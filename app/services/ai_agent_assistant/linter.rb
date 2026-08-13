# frozen_string_literal: true

# ================================================================================
# proyecto@ai_agent_assistant - F2
# ================================================================================
# Servicio: AiAgentAssistant::Linter
# Descripción: Validación ESTÁTICA de un Agente IA. Sin IA, sin red, instantánea.
#              Convierte las trampas del motor en avisos concretos antes de guardar.
#
# NIVELES
#   :error    ⛔ bloquea el guardado. Solo reglas verificables sin ambigüedad
#             (existe/no existe la feature, el archivo, el tipo de caso…).
#             Nada subjetivo puede bloquear, o el linter se vuelve un estorbo.
#   :warning  ⚠ deja guardar, avisa.
#   :info     ℹ sugerencia de estilo.
#
# La mayoría de estas reglas NO son hipotéticas: se dispararon al medir los agentes
# reales de dev.wintook.com (ver docs/asistente_agente_ia_plan.md §13).
#
# Devuelve estructura + `i18n_key` + `params`; los textos los pone el frontend.
# ================================================================================

class AiAgentAssistant::Linter # rubocop:disable Metrics/ClassLength
  VALID_KEYWORD_ACTIONS = %w[cancel pause objective_met].freeze
  PROMPT_BUDGET = 1_500
  AI_CONTEXT_BUDGET = 800 # el motor trunca ai_context a 800 en la ruta conversacional
  SEARCH_PROMPT_TOLERANCE = 200
  DUPLICATE_MIN_LENGTH = 500

  # Palabras con las que un prompt nombra su canal. Si nombra uno distinto al del
  # inbox, el agente se presenta mal (visto en 6 agentes de la cuenta 568).
  CHANNEL_WORDS = {
    'Channel::Whatsapp' => /\bwhatsapp\b/i,
    'Channel::Telegram' => /\btelegram\b/i,
    'Channel::Email' => /\b(correo electrónico|e-mail)\b/i
  }.freeze

  # Marcadores que el prompt usa como señal interna pero el motor NO limpia del
  # mensaje: el cliente los ve escritos (visto en los 4 agentes que usan keywords).
  VISIBLE_MARKER = /\A[#@]/

  RULES = %i[
    two_sources
    search_swallows_prompt
    search_kills_attachments
    inconsistent_source_names
    google_feature_missing
    erp_feature_missing
    case_type_missing
    attachment_missing
    calendar_missing
    invalid_keyword_action
    whatsapp_without_templates
    prompt_too_long
    ai_context_too_long
    channel_mismatch
    slots_without_calendars
    inbox_missing
    placeholder_looks_like_variable
    visible_keyword_marker
    duplicate_prompt
    timezone_missing
    objective_is_a_title
    sibling_versions
  ].freeze

  def initialize(template, account: nil)
    @template = template
    @account  = account || template.account
    @prompt   = template.complementary_prompt.to_s
    @inbox    = template.inbox
  end

  def call
    RULES.filter_map { |rule| send(rule) }
  end

  # Atajo para el guardado: ¿hay algo que bloquee?
  def errors?
    call.any? { |f| f[:level] == :error }
  end

  private

  attr_reader :template, :account, :prompt, :inbox

  def finding(rule, level, params = {})
    { rule: rule, level: level, i18n_key: "lint.#{rule}", params: params }
  end

  def detected
    @detected ||= AiAgentAssistant::Capabilities.detect(prompt)
  end

  def detected?(key)
    detected.any? { |c| c[:key] == key }
  end

  # Las de kind :search descartan el prompt; :source y :template no, pero compiten
  # por resolver el turno igual.
  def swallowing
    @swallowing ||= detected.select { |c| c[:swallows_prompt] }
  end

  def exclusive
    @exclusive ||= detected.select { |c| AiAgentAssistant::Capabilities::EXCLUSIVE_KINDS.include?(c[:kind]) }
  end

  # ============================ Conflicto de directivas ============================

  def two_sources
    return if exclusive.size < 2

    ganadora = exclusive.find { |c| c[:resolves_turn] }
    muertas  = exclusive.reject { |c| c[:resolves_turn] }
    finding(:two_sources, :error, winner: ganadora[:syntax], ignored: muertas.pluck(:syntax))
  end

  def search_swallows_prompt
    return if swallowing.empty?

    resto = prompt.gsub(Regexp.union(swallowing.pluck(:matcher)), '').strip
    return if resto.length <= SEARCH_PROMPT_TOLERANCE

    finding(:search_swallows_prompt, :error,
            directive: swallowing.first[:syntax], discarded_chars: resto.length)
  end

  def search_kills_attachments
    return if swallowing.empty?
    return unless detected?(:adjunto)

    finding(:search_kills_attachments, :error, directive: swallowing.first[:syntax])
  end

  # Solo se evalúa la primera coincidencia: dos nombres distintos = uno es texto muerto.
  def inconsistent_source_names
    %i[doc hoja].filter_map do |key|
      capability = AiAgentAssistant::Capabilities.find(key)
      names = prompt.scan(capability[:matcher]).flatten.map(&:strip).uniq
      next if names.size < 2

      return finding(:inconsistent_source_names, :warning, used: names.first, ignored: names[1..])
    end
    nil
  end

  # ============================ Requisitos no satisfechos ============================

  def google_feature_missing
    return unless detected?(:doc) || detected?(:hoja)
    return if account.feature_enabled?('google_calendar')

    finding(:google_feature_missing, :error)
  end

  def erp_feature_missing
    return unless detected?(:consulta)
    return if account.feature_enabled?('erp_connection')

    finding(:erp_feature_missing, :error)
  end

  def case_type_missing
    tipo = prompt[/@crear_ticket\([^)]*tipo\s*=\s*([^,)]+)/i, 1]&.strip
    return if tipo.blank?
    return if account.case_types.exists?(['LOWER(name) = ?', tipo.downcase])

    finding(:case_type_missing, :error,
            requested: tipo, available: account.case_types.pluck(:name))
  end

  def attachment_missing
    names = prompt.scan(AiAgentAssistant::Capabilities.find(:adjunto)[:matcher]).flatten.uniq
    return if names.empty?

    existing = template.persisted? ? template.ai_agent_attachments.pluck(:name).map(&:downcase) : []
    missing  = names.reject { |n| existing.include?(n.downcase) }
    return if missing.empty?

    finding(:attachment_missing, :error, missing: missing)
  end

  def calendar_missing
    return unless detected?(:agendar_calendar)
    return if template.calendar_integration_ids.present?

    finding(:calendar_missing, :error)
  end

  def invalid_keyword_action
    invalid = Array(template.keyword_actions).select do |ka|
      ka.is_a?(Hash) && VALID_KEYWORD_ACTIONS.exclude?(ka['action'].to_s)
    end
    return if invalid.empty?

    finding(:invalid_keyword_action, :error,
            actions: invalid.pluck('action'), valid: VALID_KEYWORD_ACTIONS)
  end

  # Ventana de 24 h: sin plantilla aprobada, todo reintento posterior FALLA.
  def whatsapp_without_templates
    return unless inbox&.channel_type == 'Channel::Whatsapp'
    return if Array(template.whatsapp_templates).any?
    return if retry_interval_hours < 24

    finding(:whatsapp_without_templates, :error, hours: retry_interval_hours)
  end

  # ============================ Presupuesto del motor ============================

  def prompt_too_long
    return if prompt.length <= PROMPT_BUDGET

    finding(:prompt_too_long, :warning,
            length: prompt.length, budget: PROMPT_BUDGET,
            max_tokens: AiAgentAssistant::EngineConfig.max_tokens_for(:scheduled))
  end

  def ai_context_too_long
    length = template.ai_context.to_s.length
    return if length <= AI_CONTEXT_BUDGET

    finding(:ai_context_too_long, :warning,
            length: length, budget: AI_CONTEXT_BUDGET, lost: length - AI_CONTEXT_BUDGET)
  end

  # ============================ Coherencia con la configuración ============================

  def channel_mismatch
    return if inbox.blank?

    mencionado = CHANNEL_WORDS.find { |type, re| type != inbox.channel_type && prompt.match?(re) }
    return if mencionado.blank?

    finding(:channel_mismatch, :warning,
            mentioned: mencionado.first.demodulize, actual: inbox.channel_type.demodulize)
  end

  def slots_without_calendars
    return unless template.slots_presentation == 'by_calendar'
    return if template.calendar_integration_ids.present?

    finding(:slots_without_calendars, :warning)
  end

  def inbox_missing
    return if template.inbox_id.present?

    finding(:inbox_missing, :warning)
  end

  # ============================ Estilo y operación ============================

  # Cualquier {{palabra}} sin dos puntos se interpreta como archivo. Si además NO
  # existe como adjunto, `attachment_missing` ya lo bloquea; esto avisa del caso en
  # que el nombre parece una variable de plantilla.
  def placeholder_looks_like_variable
    names = prompt.scan(AiAgentAssistant::Capabilities.find(:adjunto)[:matcher]).flatten.uniq
    sospechosos = names.grep(/\A(nombre|name|empresa|cliente|contacto|fecha)\z/i)
    return if sospechosos.empty?

    finding(:placeholder_looks_like_variable, :warning, names: sospechosos)
  end

  def visible_keyword_marker
    markers = Array(template.keyword_actions)
              .filter_map { |ka| ka['keyword'] if ka.is_a?(Hash) && ka['keyword'].to_s.match?(VISIBLE_MARKER) }
    return if markers.empty?

    finding(:visible_keyword_marker, :warning, markers: markers)
  end

  def duplicate_prompt
    return if prompt.length < DUPLICATE_MIN_LENGTH

    hermanos = account.tracking_templates
                      .where(complementary_prompt: prompt)
                      .where.not(id: template.id)
                      .pluck(:name)
    return if hermanos.empty?

    finding(:duplicate_prompt, :warning, others: hermanos)
  end

  def timezone_missing
    return unless detected?(:agendar_calendar)
    return if template.timezone.present?

    finding(:timezone_missing, :info)
  end

  def objective_is_a_title
    objective = template.objective.to_s
    return if objective.blank?
    return unless objective == objective.upcase || objective.length < 60

    finding(:objective_is_a_title, :info, length: objective.length, max: 500)
  end

  # Nombres tipo "… V4": casi siempre son versiones del mismo agente guardadas como
  # copias, no agentes distintos (visto en la cuenta 778: 6 versiones vivas).
  def sibling_versions
    base = template.name.to_s[/\A(.*?)[\s_-]*v\d+\s*\z/i, 1]
    return if base.blank?

    hermanos = account.tracking_templates
                      .where.not(id: template.id)
                      .where('name ILIKE ?', "#{base}%")
                      .pluck(:name)
    return if hermanos.empty?

    finding(:sibling_versions, :info, base: base.strip, others: hermanos)
  end

  # ============================ Helpers ============================

  def retry_interval_hours
    value = template.retry_interval_value.to_i
    case template.retry_interval_unit
    when 'minutes' then value / 60.0
    when 'hours' then value
    else value * 24
    end
  end
end
