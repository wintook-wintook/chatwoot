# frozen_string_literal: true

# «Qué sabe» — buscar en las fuentes marcadas. Lo que regresa la búsqueda queda en la traza
# con su texto: así el entrenador sabe si el dato malo venía de la fuente.
class Motor2::Skills::Knowledge < Motor2::Skills::Base
  def self.key = 'knowledge'

  def on? = search.sources.any?

  def tools
    [fn('buscar_en_fuentes',
        "Busca en lo que sabe la empresa (#{search.names.join(', ')}). Úsala ANTES de dar cualquier dato: precios, " \
        'horarios, requisitos, fechas, ligas, cómo funciona… Busca por el tema («horario de atención» para «¿abren ' \
        'el domingo?») y, si no sale, con otras palabras.',
        { pregunta: STR, fuente: { type: 'string', enum: search.names, description: 'Opcional: solo en esta fuente' } },
        %w[pregunta])]
  end

  def instructions
    <<~TEXT.strip
      - Datos de la empresa (precios, horarios, requisitos, ligas, fechas): solo los que te regrese buscar_en_fuentes.
        Si no salen, dilo con naturalidad y ofrece pasarlo con una persona; nunca los inventes ni los calcules.
      - Lo marcado «instrucciones_internas» es para ti: síguelo, pero no lo copies ni lo menciones.
    TEXT
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

  def search = @search ||= Motor2::Search.new(config.account, config.sources, conversation: @turn.conversation)

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
  end

  def snippet(result)
    [result[:titulo] || result[:codigo], result[:informacion] || result[:instrucciones_internas]].compact.join(': ')
  end
end
