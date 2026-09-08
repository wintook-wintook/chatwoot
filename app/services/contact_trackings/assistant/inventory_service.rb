# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — INVENTARIO DE LA CUENTA
# ================================================================================
# Servicio: ContactTrackings::Assistant::InventoryService
# Descripción: Reúne, SIN IA, todo lo que el Asistente de Agentes IA necesita saber
#              de una cuenta antes de proponer o redactar un Entrenamiento.
#
# EL PROBLEMA QUE RESUELVE:
#   El generador de Entrenamientos no puede adivinar los nombres propios de una
#   cuenta —qué fuentes existen, cómo se llama el foro, qué tipos de caso hay— y si
#   se lo deja, los inventa. Un Entrenamiento con @buscar_foro(Foro Soporte) cuando
#   la fuente se llama "Foro Kontrolya" parsea perfecto y no encuentra nada nunca:
#   el motor es fail-soft, así que la rama no trae resultados y nadie se entera.
#
#   Hasta ahora ese inventario lo copiaba una persona a mano antes de abrir ChatGPT
#   (docs/generador_prompts_chatgpt.md §3). Dentro de Chatwoot no es un paso: es una
#   consulta.
#
# QUÉ NO HACE:
#   · No llama a ningún modelo. Cero tokens.
#   · No escribe nada.
#   · No cachea: un inventario viejo vuelve a producir nombres que ya no existen,
#     que es justo lo que este servicio evita.
#
# CÓMO SE EVITA QUE SE DESINCRONICE DEL MOTOR:
#   Quién existe lo dice KnowledgeSource::SOURCE_TYPES; esta clase solo aporta el
#   TEXTO de cada directiva. Un tipo nuevo en el motor que nadie clasifique acá no
#   desaparece en silencio: cae en `unsupported`, se loguea, y el spec de
#   completitud falla. Es deliberado que falle ruidoso — el CI de este repo pide un
#   runner `self-hosted` que no existe, así que no hay red que lo agarre sola.
# ================================================================================

class ContactTrackings::Assistant::InventoryService
  # source_type → [plantilla de la directiva, modo que debe devolver Directives.detect]
  # El %s se reemplaza por el nombre EXACTO de la fuente. El spec hace el viaje de
  # vuelta: pasa cada directiva emitida por Directives.detect y exige que resuelva
  # al modo de la derecha, para que un cambio en las regex del motor no deje al
  # asistente dictando una gramática muerta.
  SOURCE_DIRECTIVES = {
    'canned_response' => ['@buscar_predefinidas', :canned_response],
    'article' => ['@buscar_articulo', :article],
    'discourse' => ['@buscar_foro(%s)', :knowledge_source],
    'google_doc' => ['{{doc:%s}}', :google_doc],
    'google_sheet' => ['{{hoja:%s}}', :google_sheet],
    'contpaq_support' => ['@soporte_contpaq(%s)', :contpaq_support]
  }.freeze

  # Tipos que existen en el motor y que a propósito NO se ofrecen como fuente de
  # una rama. Hoy está vacío; existe para que agregar un tipo "no direccionable"
  # sea una decisión escrita y no un olvido.
  NOT_ADDRESSABLE = [].freeze

  # Cuántos mensajes entrantes se leen para mostrar cómo escriben los clientes.
  # La descripción de una @ruta es LO ÚNICO que el clasificador usa para rutear, y
  # el contrato exige escribirla "en las palabras del cliente": estas frases son
  # esas palabras. Sin ellas la descripción sale en lenguaje de manual y clasifica
  # peor, sin que el fallo se vea.
  PHRASES_LIMIT = 40
  # Un "hola" no describe ninguna situación; un mail pegado entero tampoco sirve.
  PHRASE_MIN_LENGTH = 15
  PHRASE_MAX_LENGTH = 160

  def initialize(account, inbox: nil)
    @account = account
    @inbox = inbox
  end

  def call
    {
      sources: sources,
      unsupported: unsupported,
      canned_groups: canned_groups,
      case_types: case_types,
      labels: labels,
      customer_phrases: customer_phrases,
      erp_enabled: erp_enabled?,
      empty: empty?
    }
  end

  # Sin fuentes y sin tipos de caso no hay de dónde proponer: el asistente tiene
  # que caer a los arquetipos del manual en vez de entrevistar sobre el vacío.
  def empty?
    sources.empty? && case_types.empty?
  end

  private

  attr_reader :account, :inbox

  def active_sources
    @active_sources ||= account.knowledge_sources.active.to_a
  end

  # Se recorre SOURCE_TYPES —la lista del modelo— y no las llaves de la tabla de
  # acá: así un tipo que el motor conoce y esta clase no, se nota.
  def sources
    @sources ||= KnowledgeSource::SOURCE_TYPES.flat_map do |source_type|
      template, mode = SOURCE_DIRECTIVES[source_type]
      next [] if template.nil?

      active_sources.select { |s| s.source_type == source_type }.map do |source|
        {
          source_type: source_type,
          name: source.name,
          directive: format(template, source.name),
          mode: mode
        }
      end
    end
  end

  # Fuentes que la cuenta tiene guardadas y que el asistente no sabe ofrecer.
  # Dos orígenes posibles: un source_type nuevo en el motor sin entrada en
  # SOURCE_DIRECTIVES, o filas viejas de un tipo que ya no existe (en dev hay
  # 'ai_agent', que ninguna parte del código crea).
  def unsupported
    @unsupported ||= begin
      rows = active_sources.reject do |source|
        SOURCE_DIRECTIVES.key?(source.source_type) || NOT_ADDRESSABLE.include?(source.source_type)
      end
      rows.each do |source|
        Rails.logger.warn(
          "[Asistente] fuente sin directiva conocida: #{source.source_type.inspect} " \
          "(cuenta #{account.id}, fuente #{source.id}). No se le ofrece al modelo."
        )
      end
      rows.map { |source| { source_type: source.source_type, name: source.name } }
    end
  end

  # El "grupo" de @buscar_predefinidas(GRUPO) no es una columna ni una pantalla:
  # es el prefijo del short_code, que es lo que se vectoriza como título del ítem
  # (docs/motor_agentes_ia_manual.md §6.1). Por eso se deduce de los nombres.
  def canned_groups
    @canned_groups ||= account.canned_responses
                              .pluck(:short_code)
                              .filter_map { |code| group_prefix(code) }
                              .tally
                              .sort_by { |prefix, count| [-count, prefix] }
                              .map { |prefix, count| { prefix: prefix, count: count } }
  end

  # "GESTION - alta de usuario" → GESTION. Un short_code de una sola palabra no
  # declara ningún grupo: agruparía por sí solo y no sirve para partir el corpus.
  def group_prefix(code)
    parts = code.to_s.strip.split(/[\s\-_]+/)
    return nil if parts.size < 2

    parts.first.upcase.presence
  end

  def case_types
    @case_types ||= CaseType.where(account_id: account.id).ordered.pluck(:name)
  end

  def labels
    @labels ||= account.labels.pluck(:title)
  end

  # Se devuelven textuales, con sus typos y su jerga: eso es lo que las hace
  # útiles frente a redactar la descripción en lenguaje de manual.
  def customer_phrases
    @customer_phrases ||= begin
      scope = account.messages.where(message_type: :incoming).where.not(content: [nil, ''])
      scope = scope.where(inbox_id: inbox.id) if inbox
      scope.order(created_at: :desc)
           .limit(PHRASES_LIMIT * 3)
           .pluck(:content)
           .map { |content| content.to_s.squish }
           .select { |content| content.length.between?(PHRASE_MIN_LENGTH, PHRASE_MAX_LENGTH) }
           .uniq
           .first(PHRASES_LIMIT)
    end
  end

  def erp_enabled?
    account.feature_enabled?('erp_connection')
  end
end
