# frozen_string_literal: true

# ================================================================================
# proyecto@ai_agent_assistant - F1
# ================================================================================
# Servicio: AiAgentAssistant::Capabilities
# Descripción: Catálogo declarativo de lo que un Agente IA sabe hacer. Es la FUENTE
#              ÚNICA de la que leen el chat, el linter y el probador.
#
# AGREGAR UNA DIRECTIVA FUTURA = AGREGAR UNA ENTRADA AQUÍ.
# Un spec (spec/services/ai_agent_assistant/capabilities_spec.rb) falla en CI si el
# motor reconoce una directiva que no está registrada: es el guardarraíl que evita
# que este catálogo se desincronice del código en silencio.
#
# LOS TRES COMPORTAMIENTOS QUE HAY QUE DISTINGUIR (verificados en código):
#
#   swallows_prompt: las 4 directivas de búsqueda (@buscar_predefinidas,
#     @buscar_articulo, @buscar_foro, @discourse) hacen que el motor descarte el
#     complementary_prompt ENTERO en la ruta conversacional (clean_cp = '' en
#     ContactTrackingResponseAnalyzerJob). Con ellas el agente pierde su voz propia
#     y también el envío de adjuntos.
#
#   {{doc:}} y {{hoja:}} NO están en esa lista: conservan el prompt y solo resuelven
#     el turno en el que aplican. Son la única vía para tener voz propia y
#     conocimiento a la vez.
#
#   renders_prompt: con {{consulta:}} el complementary_prompt deja de ser
#     instrucciones y se envía LITERAL al cliente, ya interpolado y sin pasar por
#     la IA (KnowledgeBaseResponseService#perform_erp_query).
#
# Los textos de UI NO viven aquí: la API devuelve estructura + `i18n_key` y el
# frontend los traduce desde aiAgentAssistant.json (convención del módulo: código en
# inglés, UI en español con `en` completo).
# ================================================================================

# ALL es una tabla declarativa, no lógica: su tamaño es el del catálogo del motor y
# crecerá cada vez que se agregue una directiva. Partirla en clases no la haría más
# legible, solo repartiría la misma tabla en dos sitios.
class AiAgentAssistant::Capabilities # rubocop:disable Metrics/ClassLength
  # Orden exacto de evaluación de KnowledgeBaseResponseService#detect_directive.
  # Solo una resuelve el turno: la primera que coincide gana y el resto es texto muerto.
  ALL = [
    {
      key: :consulta,
      syntax: '{{consulta:conexion/nombre(args)}}',
      matcher: ExternalDb::ConsultaDirectiveRenderer::DIRECTIVE,
      kind: :template,
      precedence: 1,
      requirement: :feature_erp_connection,
      swallows_prompt: false,
      renders_prompt: true,
      example: 'Su saldo al día de hoy es {{consulta:contpaq/saldo_cliente}}'
    },
    {
      key: :buscar_predefinidas,
      syntax: '@buscar_predefinidas',
      matcher: /@buscar_predefinidas\b/i,
      kind: :search,
      precedence: 2,
      requirement: :knowledge_items_canned_response,
      swallows_prompt: true,
      renders_prompt: false,
      example: '@buscar_predefinidas'
    },
    {
      key: :buscar_articulo,
      syntax: '@buscar_articulo',
      matcher: /@buscar_art[ií]culo\b/i,
      kind: :search,
      precedence: 3,
      requirement: :knowledge_items_article,
      swallows_prompt: true,
      renders_prompt: false,
      example: '@buscar_articulo'
    },
    {
      key: :buscar_foro,
      syntax: '@buscar_foro(nombre_de_la_fuente)',
      matcher: /@buscar_foro\(([^)]+)\)/i,
      kind: :search,
      precedence: 4,
      requirement: :knowledge_sources_discourse,
      swallows_prompt: true,
      renders_prompt: false,
      example: '@buscar_foro(Manual Kontrolya)'
    },
    {
      key: :doc,
      syntax: '{{doc:Nombre del documento}}',
      matcher: /\{\{doc:([^}]+)\}\}/i,
      kind: :source,
      precedence: 5,
      requirement: :feature_google_calendar,
      swallows_prompt: false,
      renders_prompt: false,
      example: '{{doc:Políticas de garantía}}'
    },
    {
      key: :hoja,
      syntax: '{{hoja:Nombre de la hoja}}',
      matcher: /\{\{hoja:([^}]+)\}\}/i,
      kind: :source,
      precedence: 6,
      requirement: :feature_google_calendar,
      swallows_prompt: false,
      renders_prompt: false,
      example: '{{hoja:Precios 2026}}'
    },
    {
      key: :discourse,
      syntax: '@discourse',
      matcher: /@discourse\b/i,
      kind: :search,
      precedence: 7,
      requirement: :discourse_hook_on_inbox,
      swallows_prompt: true,
      renders_prompt: false,
      example: '@discourse'
    },
    {
      key: :agendar_calendar,
      syntax: '@agendar_calendar',
      matcher: /@agendar_calendar\b/i,
      kind: :flag,
      precedence: nil,
      requirement: :calendar_integrations,
      swallows_prompt: false,
      renders_prompt: false,
      example: '@agendar_calendar'
    },
    {
      key: :crear_ticket,
      syntax: '@crear_ticket(prioridad=alta, tipo=Soporte)',
      matcher: Cases::TicketCreatorService::DIRECTIVE_RE,
      kind: :flag,
      precedence: nil,
      requirement: :case_types,
      swallows_prompt: false,
      renders_prompt: false,
      example: '@crear_ticket(prioridad=alta, tipo=Soporte)'
    },
    {
      key: :estado_ticket,
      syntax: '@estado_ticket',
      matcher: /#{Regexp.escape(Cases::TicketStatusService::DIRECTIVE)}\b/i,
      kind: :flag,
      precedence: nil,
      requirement: :case_types,
      swallows_prompt: false,
      renders_prompt: false,
      example: '@estado_ticket'
    },
    {
      key: :adjunto,
      syntax: '{{nombre_del_archivo}}',
      matcher: ContactTrackingResponseAnalyzerJob::ATTACHMENT_DIRECTIVE,
      kind: :attachment,
      precedence: nil,
      requirement: :template_attachments,
      swallows_prompt: false,
      renders_prompt: false,
      example: 'Te comparto el {{catalogo}}'
    }
  ].freeze

  # Las de kind :search y :source compiten por resolver el turno: solo una aplica.
  EXCLUSIVE_KINDS = %i[search source template].freeze

  class << self
    def all
      ALL
    end

    def find(key)
      ALL.find { |c| c[:key].to_s == key.to_s }
    end

    def keys
      ALL.pluck(:key)
    end

    # Las que, de estar presentes, descartan el complementary_prompt entero.
    def prompt_swallowing
      ALL.select { |c| c[:swallows_prompt] }
    end

    # Detecta qué capacidades usa un prompt. Devuelve las entradas del catálogo,
    # en orden de precedencia; `resolves_turn` marca cuál gana realmente.
    def detect(prompt)
      text  = prompt.to_s
      found = ALL.select { |c| text.match?(c[:matcher]) }
      winner = found.select { |c| EXCLUSIVE_KINDS.include?(c[:kind]) }
                    .min_by { |c| c[:precedence] || Float::INFINITY }

      found.map { |c| c.merge(resolves_turn: EXCLUSIVE_KINDS.exclude?(c[:kind]) || c == winner) }
    end

    # Catálogo resuelto contra el estado REAL de la cuenta: qué está disponible,
    # qué no, y por qué. Es lo que consume la UI y, más adelante, el linter.
    def resolve_for(account:, inbox: nil, template: nil)
      ALL.map do |capability|
        available, detail = availability(capability[:requirement], account, inbox, template)

        capability.except(:matcher).merge(
          i18n_key: "capabilities.#{capability[:key]}",
          available: available,
          detail: detail
        )
      end
    end

    private

    # Cada requisito se resuelve en su propio método: [disponible?, detalle], donde
    # `detalle` da contexto útil a la UI (nombres de fuentes, cuántos artículos hay…).
    RESOLVERS = {
      feature_erp_connection: :resolve_erp_connection,
      feature_google_calendar: :resolve_google_calendar,
      knowledge_items_canned_response: :resolve_canned_responses,
      knowledge_items_article: :resolve_articles,
      knowledge_sources_discourse: :resolve_knowledge_sources,
      discourse_hook_on_inbox: :resolve_discourse_hook,
      calendar_integrations: :resolve_calendars,
      case_types: :resolve_case_types,
      template_attachments: :resolve_attachments
    }.freeze

    def availability(requirement, account, inbox, template)
      resolver = RESOLVERS[requirement]
      return [true, nil] if resolver.blank?

      send(resolver, account, inbox, template)
    rescue StandardError => e
      Rails.logger.warn "[Capabilities] No se pudo resolver #{requirement}: #{e.message}"
      [false, nil]
    end

    # No basta con que la feature esté encendida: la directiva se escribe
    # {{consulta:conexion/consulta}} y sin los nombres reales nadie —ni el asistente—
    # puede componer una que resuelva.
    def resolve_erp_connection(account, _inbox, _template)
      return [false, nil] unless account.feature_enabled?('erp_connection')

      names = account.external_db_queries.where(active: true).includes(:external_db_connection)
                     .filter_map { |query| "#{query.external_db_connection&.name}/#{query.name}" }
                     .uniq
      [names.any?, { names: names }]
    end

    def resolve_google_calendar(account, _inbox, _template)
      [account.feature_enabled?('google_calendar'), nil]
    end

    def resolve_canned_responses(account, _inbox, _template)
      count = account.knowledge_items.where(source_type: 'canned_response').count
      [count.positive?, { count: count }]
    end

    def resolve_articles(account, _inbox, _template)
      count = account.knowledge_items.where(source_type: 'article').count
      [count.positive?, { count: count }]
    end

    def resolve_knowledge_sources(account, _inbox, _template)
      names = account.knowledge_sources.active.where(source_type: 'discourse').pluck(:name)
      [names.any?, { names: names }]
    end

    def resolve_discourse_hook(account, inbox, _template)
      return [false, nil] if inbox.blank?

      [account.hooks.exists?(app_id: 'discourse', inbox_id: inbox.id, status: 'enabled'), nil]
    end

    def resolve_calendars(account, _inbox, _template)
      count = UserCalendarIntegration.where(account_id: account.id).count
      [count.positive?, { count: count }]
    end

    def resolve_case_types(account, _inbox, _template)
      names = account.case_types.pluck(:name)
      [names.any?, { names: names }]
    end

    def resolve_attachments(_account, _inbox, template)
      names = template.present? ? template.ai_agent_attachments.pluck(:name) : []
      [names.any?, { names: names }]
    end
  end
end
