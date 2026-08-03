# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Directiva @crear_ticket (intake IA)
# ================================================================================
# Servicio: Cases::TicketCreatorService
# Responsabilidad: al detectar @crear_ticket en el complementary_prompt, crea un
# CaseTicket BIEN FORMADO usando Cases::Ai::Intake (lee la conversación y arma
# título/descripción/clasificación), aplicando además:
#   - Directiva parametrizable:  @crear_ticket(prioridad=alta, tipo=Soporte)
#   - Anti-duplicado (§11.2): si el contacto ya tiene un caso abierto, lo reusa.
#   - Score de riesgo (§11.3): reincidencia + churn suben la prioridad.
#   - Fase 2 (§6): si falta un dato clave, lo pide UNA vez antes de crear.
#   - Degradación: si la IA no está disponible/falla, cae al alta básica de antes.
#
# Retorna true si actuó (creó/reusó ticket o pidió un dato), false si no.
# Ver: docs/vault-tickets/implementacion/Plan-Crear-Ticket-IA.md
#
# Posición en el flujo del job (try_kbase_then_conversational):
#   [1] @estado_ticket                → Cases::TicketStatusService
#   [2] Cases::TicketCreatorService   → este servicio
#   [3] @agendar_calendar
#   [4] KnowledgeBaseResponseService  → último recurso (§11.1): si resuelve, no llega a [5]
#   [5] generate_and_send_conversational_reply (fallback)
# ================================================================================

class Cases::TicketCreatorService
  DIRECTIVE_RE = /@crear_ticket(?:\(([^)]*)\))?/i

  PRIORITY_ORDER = %w[low medium high urgent].freeze
  # Sinónimos ES → enum, para @crear_ticket(prioridad=…).
  PRIORITY_ALIASES = {
    'baja' => 'low', 'media' => 'medium', 'normal' => 'medium',
    'alta' => 'high', 'urgente' => 'urgent', 'critica' => 'urgent', 'crítica' => 'urgent'
  }.freeze
  # Ventana para "reincidente": nº de tickets del contacto en los últimos N días.
  REINCIDENCE_DAYS = 14
  REINCIDENCE_THRESHOLD = 2
  PENDING_TTL = 1.hour
  # Máximo de turnos en que el bot insiste por datos faltantes antes de crear igual.
  MAX_FIELD_ASKS = 2

  # Llave de la recolección de campos en curso (Fase 2).
  def self.pending_key(conversation_id)
    "case_intake_pending::#{conversation_id}"
  end

  # Qué hizo el último create_if_needed: :no_directive, :linked_existing,
  # :not_worthy, :asked_missing_fields, :created o :error. Permite a callers como
  # el gate de @agendar_calendar distinguir "acabo de pedir un dato, no agendes
  # todavía" de "ya hay ticket / no aplica, seguí con el flujo normal".
  attr_reader :outcome

  def initialize(message, tracking:)
    @message      = message
    @tracking     = tracking
    @account      = message.account
    @conversation = message.conversation
    @contact      = message.conversation.contact
    @outcome      = :no_directive
  end

  def create_if_needed
    return false unless directive_present?
    # §11.2 Anti-duplicado: reusa caso abierto
    return finish(:linked_existing, true) if reuse_existing_ticket

    fields = intake_fields # nil = IA no disponible → degradar

    if fields
      # Gate: si la conversación no amerita un ticket (saludo, charla, tema resuelto),
      # NO creamos nada y dejamos que el bot responda normal. Evita tickets espurios.
      return finish(:not_worthy, false) if not_ticket_worthy?(fields)

      # Campos particulares del tipo + Fase 2 (§6): extrae los case_type_fields de la
      # conversación y, si faltan OBLIGATORIOS (o missing_info cuando el tipo no define
      # campos), los pide y espera. true = el turno YA se atendió.
      return finish(:asked_missing_fields, true) if request_missing_fields(fields)
    end

    created = create_and_confirm(fields)
    finish(created ? :created : :error, created)
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error creando ticket: #{e.message}"
    finish(:error, false)
  end

  private

  # Registra el outcome de create_if_needed y devuelve `result` (azúcar para poder
  # usarlo en un `return` de una sola línea).
  def finish(outcome, result)
    @outcome = outcome
    result
  end

  # §11.2 Anti-duplicado: si ya hay un caso abierto del contacto, lo reusa y avisa.
  def reuse_existing_ticket
    existing = orchestrator.find_active_ticket
    return false unless existing

    link_and_confirm_existing(existing)
    true
  end

  # Construye el ticket (con campos capturados), aplica reglas y confirma al cliente.
  def create_and_confirm(fields)
    ticket = build_ticket(directive_overrides, fields)
    return false unless ticket

    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    send_confirmation(ticket)
    true
  end

  def directive_present?
    @tracking&.complementary_prompt.to_s.match?(DIRECTIVE_RE)
  end

  # true si la conversación NO amerita ticket (cierra el ciclo de Fase 2 si lo hubo).
  def not_ticket_worthy?(fields)
    return false unless fields['ticket_worthy'] == false

    Redis::Alfred.delete(pending_key)
    true
  end

  def orchestrator
    @orchestrator ||= Cases::OrchestratorService.new(
      account: @account, contact: @contact, conversation: @conversation
    )
  end

  # ---------------------------------------------------------------------------
  # Construcción del ticket: intake IA (+ degradación) → create_from_ai.
  # `fields` = salida del intake, o nil si la IA no está disponible.
  # ---------------------------------------------------------------------------
  def build_ticket(overrides, fields)
    # Degradación: sin IA disponible → alta básica de siempre (título recortado).
    return degraded_ticket if fields.nil?

    forced_priority = resolve_forced_priority(overrides, fields)

    orchestrator.create_from_ai(
      message: @message,
      tracking: @tracking,
      title: fields['title'],
      description: fields['description'],
      priority: forced_priority,
      case_type_id: resolve_case_type_id(overrides, fields),
      ticket_kind: fields['ticket_kind'],
      impact: fields['impact'],
      urgency: fields['urgency'],
      affected_service_id: fields['affected_service_id'],
      category_id: fields['category_id'],
      custom_attributes: intake_custom_attributes(fields),
      force_priority: forced_priority.present?
    )
  end

  # Alta básica anterior (sin IA): título recortado + clasificación async.
  def degraded_ticket
    orchestrator.find_or_create_from_message(@message, tracking: @tracking)
  end

  # Llama al intake IA. nil si la cuenta no tiene IA (key) o la clasificación está
  # apagada, o si el LLM falla → el caller degrada.
  def intake_fields
    return nil unless CaseAiConfig.for_account(@account).active?(:classify)

    intake = Cases::Ai::Intake.new(account: @account)
    return nil unless intake.available?

    intake.extract(conversation_text: conversation_text, policy: policy_prompt)
  end

  # ---------------------------------------------------------------------------
  # Directiva parametrizable: @crear_ticket(prioridad=alta, tipo=Soporte)
  # ---------------------------------------------------------------------------
  def directive_overrides
    m = @tracking.complementary_prompt.to_s.match(DIRECTIVE_RE)
    return {} unless m && m[1].present?

    m[1].split(',').each_with_object({}) do |pair, h|
      k, v = pair.split('=', 2).map { |s| s.to_s.strip }
      h[k.downcase] = v if k.present? && v.present?
    end
  end

  # Precedencia de prioridad: directiva > riesgo > (matriz/medium). Devuelve la
  # prioridad FORZADA (string) o nil para dejar que la matriz/impacto decidan.
  def resolve_forced_priority(overrides, fields)
    forced = normalize_priority(overrides['prioridad'])
    return forced if forced.present?

    risk_bumped_priority(fields)
  end

  def normalize_priority(value)
    return nil if value.blank?

    key = value.to_s.strip.downcase
    key = PRIORITY_ALIASES[key] || key
    PRIORITY_ORDER.include?(key) ? key : nil
  end

  # §11.3 Score de riesgo: parte de la prioridad de la matriz (o media) y la sube
  # un nivel si el intake detectó churn o el contacto es reincidente.
  def risk_bumped_priority(fields)
    return nil unless risky?(fields)

    base = Cases::PriorityMatrix.derive(fields['impact'], fields['urgency']) || 'medium'
    bump(base)
  end

  def risky?(fields)
    fields['churn_risk'] == true || reincident?
  end

  def reincident?
    return false unless @contact

    @account.case_tickets
            .where(contact_id: @contact.id)
            .where('created_at >= ?', REINCIDENCE_DAYS.days.ago)
            .count >= REINCIDENCE_THRESHOLD
  end

  def bump(priority, steps: 1)
    i = PRIORITY_ORDER.index(priority) || 1
    PRIORITY_ORDER[[i + steps, PRIORITY_ORDER.size - 1].min]
  end

  # Tipo por nombre desde la directiva (@crear_ticket(tipo=Soporte)); si no, el
  # que infirió el intake.
  def resolve_case_type_id(overrides, fields)
    name = overrides['tipo']
    if name.present?
      id = @account.case_types.where('LOWER(name) = ?', name.downcase).pick(:id)
      return id if id
    end
    fields['case_type_id']
  end

  # Deja rastro del intake en el ticket (para el asesor y auditoría) y guarda los
  # valores capturados de los campos particulares del tipo, cada uno bajo su `key`.
  def intake_custom_attributes(fields)
    attrs = {}
    attrs['churn_risk'] = true if fields['churn_risk']
    attrs.merge!(@field_values) if @field_values.present?
    attrs['ai_intake'] = {
      'confidence' => fields['confidence'],
      'reasoning' => fields['reasoning'],
      'missing_info' => fields['missing_info']
    }.compact
    attrs
  end

  # ---------------------------------------------------------------------------
  # Campos particulares del tipo de caso (case_type_fields)
  # ---------------------------------------------------------------------------
  # Tras conocer el tipo, extrae de la conversación los valores de sus campos y
  # detecta los OBLIGATORIOS faltantes. Deja @field_values, @missing_required y
  # @type_has_fields para el resto del flujo.
  def resolve_type_and_fields(fields)
    @field_values     = {}
    @missing_required = []
    case_type         = case_type_with_fields(fields)
    @type_has_fields  = case_type.present?
    return unless @type_has_fields && field_extractor.available?

    result            = field_extractor.extract(conversation_text: conversation_text, case_type: case_type)
    @field_values     = result['values'] || {}
    @missing_required = result['missing_required'] || []
  rescue StandardError => e
    Rails.logger.error("[TicketCreator] Error extrayendo campos del tipo: #{e.message}")
  end

  # El tipo de caso resuelto SOLO si tiene campos particulares definidos; si no, nil.
  def case_type_with_fields(fields)
    type_id = resolve_case_type_id(directive_overrides, fields || {})
    return if type_id.blank?

    case_type = @account.case_types.includes(:case_type_fields).find_by(id: type_id)
    return if case_type.nil? || case_type.case_type_fields.empty?

    case_type
  end

  # Extrae los campos del tipo y, si faltan datos que pedir, los solicita. Devuelve
  # true si preguntó (turno atendido), false si no hay nada pendiente. En ambos casos
  # deja @field_values listo para build_ticket.
  def request_missing_fields(fields)
    resolve_type_and_fields(fields)
    missing = missing_info_to_ask(fields)
    return false unless missing.present? && ask_for_missing_info?(missing)

    request_missing_info(missing)
    true
  end

  # Qué datos pedir: si el tipo define campos, SOLO los obligatorios faltantes
  # (etiquetados y con opciones para las listas); si no, el missing_info del intake.
  def missing_info_to_ask(fields)
    if @type_has_fields
      Array(@missing_required).map { |field| field_ask_label(field) }
    else
      Array(fields['missing_info'])
    end
  end

  def field_ask_label(field)
    return field.label unless field.field_list?

    opts = Array(field.options).join(', ')
    opts.present? ? "#{field.label} (opciones: #{opts})" : field.label
  end

  def field_extractor
    @field_extractor ||= Cases::Ai::FieldExtractor.new(account: @account)
  end

  # ---------------------------------------------------------------------------
  # Fase 2 (§6): pedir los datos faltantes (obligatorios del tipo o missing_info).
  # Se permite un número acotado de vueltas (MAX_FIELD_ASKS) para dar de alta el
  # caso aunque el cliente no complete todo, sin quedar en bucle. Estado en Redis.
  # ---------------------------------------------------------------------------
  def ask_for_missing_info?(missing)
    return false if missing.blank?

    Redis::Alfred.get(pending_key).to_i < MAX_FIELD_ASKS
  end

  def request_missing_info(missing)
    asks = Redis::Alfred.get(pending_key).to_i + 1
    Redis::Alfred.setex(pending_key, asks.to_s, PENDING_TTL)
    intro = missing.size == 1 ? 'necesito un dato' : 'necesito unos datos'
    text  = "Para poder levantar tu caso #{intro}: #{to_sentence_es(missing)}. " \
            '¿Me lo compartes, por favor?'
    deliver(text)
  end

  def pending_key
    self.class.pending_key(@conversation.id)
  end

  # to_sentence usa conectores en inglés ("and") salvo que el locale los defina, y
  # aquí no están (no hay rails-i18n ni support.array en es.yml). Se pasan a mano.
  def to_sentence_es(list)
    list.to_sentence(words_connector: ', ', two_words_connector: ' y ', last_word_connector: ' y ')
  end

  # ---------------------------------------------------------------------------
  # Confirmaciones al cliente
  # ---------------------------------------------------------------------------
  def link_and_confirm_existing(ticket)
    ticket.update(conversation: @conversation) if ticket.conversation_id.nil?
    folio = ticket.folio.presence || "##{ticket.id}"
    deliver("Ya tienes el caso #{folio} en curso; sumé tu mensaje a ese caso. " \
            'Un asesor te contactará a la brevedad.')
    ticket.case_events.create!(
      account: @account, event_type: :message_sent, origin: :bot,
      payload: { ticket_id: ticket.id, linked: true }
    )
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error vinculando caso existente: #{e.message}"
  end

  def send_confirmation(ticket)
    Redis::Alfred.delete(pending_key) # cierra el ciclo de Fase 2 si lo hubo
    folio = ticket.folio.presence || "##{ticket.id}"
    text  = "Tu caso #{folio} fue registrado. Un asesor te contactará a la brevedad."
    deliver(text)

    ticket.case_events.create!(
      account: @account,
      event_type: :message_sent,
      origin: :bot,
      payload: { content: text, ticket_id: ticket.id }
    )
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error enviando confirmación: #{e.message}"
  end

  def deliver(text)
    reply = Messages::MessageBuilder.new(
      bot_user, @conversation, { content: text, private: false }
    ).perform
    return if reply.blank?

    reply.content_attributes[:ticket_created] = true
    reply.save!
  end

  # ---------------------------------------------------------------------------
  # Contexto y política para el intake
  # ---------------------------------------------------------------------------
  # Transcripción reciente de la conversación (Cliente/Bot: …) para que el intake
  # tenga contexto, no solo el último mensaje.
  def conversation_text
    @conversation_text ||= build_conversation_text
  end

  def build_conversation_text
    msgs = Message.where(conversation_id: @conversation.id)
                  .where(message_type: [0, 1])
                  .reorder(created_at: :desc)
                  .limit(8)
                  .reverse
    msgs.map do |m|
      who = m.incoming? ? 'Cliente' : 'Bot'
      "#{who}: #{m.content.to_s.strip.truncate(200)}"
    end.join("\n").presence || @message.content.to_s.strip
  rescue StandardError
    @message.content.to_s.strip
  end

  # El prompt complementario como política de negocio, SIN las directivas técnicas
  # (que son instrucciones para el sistema, no reglas para el intake).
  def policy_prompt
    @tracking.complementary_prompt.to_s
             .gsub(DIRECTIVE_RE, '')
             .gsub(/@[a-z_]+(\([^)]*\))?/i, '')
             .strip
             .presence
  end

  def bot_user
    @account.users.first ||
      AccountUser.where(account_id: @account.id).first&.user ||
      User.first
  end
end
