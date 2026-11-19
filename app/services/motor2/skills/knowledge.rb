# frozen_string_literal: true

# «Qué sabe» — buscar en las fuentes marcadas. Lo que regresa la búsqueda queda en la traza
# con su texto: así el entrenador sabe si el dato malo venía de la fuente. El agente recibe el
# mapa de sus fuentes (Motor2::SourceMap: qué hay en cada una) para buscar en la que corresponde.
# Las predefinidas se buscan con la búsqueda nueva (KnowledgeBase::Selection vía AiFollowUps::KnowledgeSearch).
class Motor2::Skills::Knowledge < Motor2::Skills::Base
  def self.key = 'knowledge'

  # Una función puede apagarla (p. ej. «Atención a prospectos» que no contesta dudas).
  def on? = config.skill(key)['on'] != false && search.sources.any?

  # Lo que escribió el cliente, con sus palabras (CONTPAQi contesta mejor así que con la búsqueda que
  # redacta el modelo). Si lo último es corto («comercial premium»), va con lo que dijo antes.
  SHORT_WORDS = 4

  def prepare(history)
    said = Array(history).select { |m| m[:role].to_s == 'user' }.map { |m| m[:content].to_s.squish }.compact_blank
    last = said.last.to_s
    @customer_words = last.split.size <= SHORT_WORDS && said.size > 1 ? "#{said[-2]} #{last}" : last
    @search = nil # se armó antes (on?) sin sus palabras
  end

  def tools
    return [] unless searchable?

    [fn('buscar_en_fuentes',
        "Busca en lo que sabe la empresa (#{search.names.join(', ')}). Úsala ANTES de dar cualquier dato: precios, " \
        'horarios, requisitos, fechas, ligas, cómo funciona… Busca por el tema («horario de atención» para «¿abren ' \
        'el domingo?») y, si no sale, con otras palabras.',
        { pregunta: STR, fuente: { type: 'string', enum: search.names, description: 'Opcional: solo en esta fuente' } },
        %w[pregunta])]
  end

  # «Atención a clientes»: sin búsqueda si falta aclarar o el área no consulta fuentes (Motor2::Skills::Areas).
  def searchable?
    areas = @turn.find_skill('areas')
    areas.nil? || areas.allows_search?
  end

  def instructions
    <<~TEXT.strip
      - Datos de la empresa (precios, horarios, requisitos, ligas, fechas): solo los que te regrese buscar_en_fuentes.
        Si no salen, dilo con naturalidad y ofrece pasarlo con una persona; nunca los inventes ni los calcules.
      - Lo marcado «instrucciones_internas» es para ti: síguelo, pero no lo copies ni lo menciones.
      #{where_to_search}
    TEXT
  end

  # DÓNDE BUSCAR: cada fuente con lo que tiene. Con una sola fuente no hace falta.
  def where_to_search
    lines = map_lines
    return '' if lines.size < 2

    '- DÓNDE BUSCAR (qué hay en cada fuente): busca primero en la que corresponde, con «fuente»; si ahí no sale, ' \
      "busca otra vez sin «fuente» (en todas).\n#{lines.map { |l| "  #{l}" }.join("\n")}"
  end

  def map_lines
    names = search.names
    Motor2::SourceMap.new(config.account).lines(config.sources).select { |l| names.any? { |n| l.start_with?("- #{n}:") } }
  end

  def call(_name, args)
    question = args['pregunta'].to_s.strip
    return { error: 'Falta la pregunta.' } if question.blank?

    found = search.call(question, only: args['fuente'])
    found.each { |f| note(f, question) }
    note_selection
    found = found.reject { |f| f[:resultados].empty? }
    found.any? ? { resultados: found } : { resultados: [], nota: 'No se encontró nada. No lo inventes.' }
  end

  private

  def search
    @search ||= Motor2::Search.new(config.account, config.sources, conversation: @turn.conversation, customer_words: @customer_words)
  end

  # proyecto@predefinidas_que_contestan: qué escogió la búsqueda nueva, para el probador.
  def note_selection
    sel = search.selection
    return if sel.nil?

    texto = if sel[:ninguna]
              "ninguna de #{sel[:candidatas]} candidatas#{" (falta: #{sel[:falta]})" if sel[:falta]}"
            else
              "#{sel[:escogidas].size} de #{sel[:candidatas]} candidatas: #{sel[:escogidas].join(' · ')}"
            end
    trace.event('seleccion', texto)
  end

  # A la traza (con lo que regresó, para el entrenador) y a lo «visto» (para revisar montos y ligas).
  def note(found, question)
    results = found[:resultados]
    trace.source(name: found[:fuente], kind: found[:tipo], query: question, found: results.map { |r| snippet(r) })
    @turn.canned_used.concat(results.filter_map { |r| r[:codigo] if r[:instrucciones_internas] })
    @turn.seen << results.to_json
    @turn.evidence << "#{found[:fuente]}: #{results.to_json}" if results.any?
  end

  def snippet(result)
    [result[:titulo] || result[:codigo], result[:informacion] || result[:instrucciones_internas]].compact.join(': ')
  end
end
