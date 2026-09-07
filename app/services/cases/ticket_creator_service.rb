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
  # @crear_ticket_multiple (2026-09-04, docs/vault-tickets Pendiente.md) — alias que activa
  # el modo "múltiples tickets" (ver `multiple_mode?`): el `(?:_multiple)?` opcional deja
  # intacta la captura de parámetros para AMBAS formas, así que @crear_ticket(...) de
  # siempre no cambia en nada.
  DIRECTIVE_RE = /@crear_ticket(?:_multiple)?(?:\(([^)]*)\))?/i
  MULTIPLE_DIRECTIVE_RE = /@crear_ticket_multiple\b/i

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
  # Valores que @crear_ticket(fallback=...) acepta como "verdadero" (ver `fallback?`).
  TRUTHY_VALUES = %w[true si sí 1].freeze
  # Máximo de turnos en que el bot insiste por datos faltantes antes de crear igual.
  MAX_FIELD_ASKS = 2
  # Guard anti-loop (§11.2): cuántas veces seguidas se le repite al contacto "ya tienes
  # un caso en curso" antes de escalar a un humano en vez de insistir con el mismo texto
  # fijo. Cubre el caso de un contacto que sigue pidiendo algo (ej. "quiero un nuevo
  # ticket", "dame la agenda de X") que esta respuesta no contesta.
  MAX_LINKED_REPEATS = 2
  # @crear_ticket_multiple — cuánto dura la espera de "¿es un caso nuevo o el mismo?"
  # antes de que una respuesta tardía del cliente ya no cuente como confirmación.
  NEW_REQUEST_CONFIRM_TTL = 1.hour

  # Llave de la recolección de campos en curso (Fase 2).
  def self.pending_key(conversation_id)
    "case_intake_pending::#{conversation_id}"
  end

  # Llave del contador de repeticiones de "ya tienes un caso en curso" (guard anti-loop).
  def self.linked_repeat_key(conversation_id)
    "case_intake_linked_repeat::#{conversation_id}"
  end

  # Llave de "le pregunté al cliente si esto es un caso nuevo, esperando que conteste".
  def self.new_request_confirm_key(conversation_id)
    "case_new_request_confirm::#{conversation_id}"
  end

  # Llave del mensaje desde el que arranca una solicitud nueva ya confirmada — acota el texto
  # que lee el intake al construir su ticket (ver `apply_new_request_conversation_scope!`).
  def self.new_request_source_message_key(conversation_id)
    "case_new_request_source_message::#{conversation_id}"
  end

  # 2026-09-05 (conv. #148: loop de "¿es lo mismo o es nuevo?") — a diferencia de
  # `new_request_confirm_key` (de un solo uso, se borra al leerla), esta marca dura TODA la
  # recolección de datos del servicio nuevo confirmado — puede tomar varios turnos si
  # @disponibilidad_calendar no logra armar la agenda en el primer intento. Mientras esté puesta,
  # `reuse_existing_ticket` no vuelve a preguntar "¿es lo mismo o es nuevo?": trata la
  # conversación como si no hubiera ningún caso activo de por medio. Se borra al crear el ticket
  # nuevo (`create_after_appointment`) o expira sola (mismo TTL que el resto del flujo).
  def self.new_request_in_progress_key(conversation_id)
    "case_new_request_in_progress::#{conversation_id}"
  end

  def self.clear_new_request_in_progress(conversation_id)
    Redis::Alfred.delete(new_request_in_progress_key(conversation_id))
  end

  # @crear_ticket(fallback=true): invierte la posición del alta de ticket dentro del
  # turno. Por defecto el ticket se evalúa ANTES que la KBase (§11.1); con el flag pasa
  # a ser el ÚLTIMO recurso: primero contesta la base de conocimiento y el caso solo se
  # levanta si la búsqueda no resolvió el turno. Sin el flag, el orden de siempre.
  def self.fallback?(tracking)
    m = tracking&.complementary_prompt.to_s.match(DIRECTIVE_RE)
    return false unless m && m[1].present?

    m[1].split(',').any? do |pair|
      k, v = pair.split('=', 2).map { |x| x.to_s.strip.downcase }
      k == 'fallback' && TRUTHY_VALUES.include?(v)
    end
  end

  # Qué hizo el último create_if_needed: :no_directive, :linked_existing,
  # :not_worthy, :asked_missing_fields, :escalated, :escalated_multiple,
  # :escalated_repeat, :split_by_resource, :created o :error — y con
  # @crear_ticket_multiple también :technical_question, :asked_new_request_confirmation.
  # Permite a callers como el
  # gate de @agendar_calendar distinguir "acabo de pedir un dato, no agendes todavía" de
  # "ya hay ticket / no aplica, seguí con el flujo normal". :escalated,
  # :escalated_multiple, :escalated_repeat y :split_by_resource tampoco agendan por la
  # vía normal (no son :created ni :linked_existing) — :split_by_resource agenda cada
  # tracking hijo por su cuenta, ver `spawned_trackings`. :escalated_repeat es el guard
  # anti-loop de §11.2: el contacto ya escuchó "ya tienes un caso en curso" demasiadas
  # veces sin que su pedido avance, así que se corta y se escala.
  attr_reader :outcome

  # Con outcome == :split_by_resource: un ContactTracking nuevo por cada recurso del
  # catálogo resuelto (ej. una grúa concreta), cada uno con su propio ticket ya creado
  # y su calendario acotado a ESE recurso. El caller (el job) ofrece la disponibilidad
  # de cada uno por separado.
  attr_reader :spawned_trackings

  # true si el intake detectó una pregunta técnica del cliente sin responder en el turno (ej.
  # conv. #55: "qué camión me puede ayudar" junto con el pedido). El ticket se crea igual — el
  # caller (el job) es quien decide, con esto, NO ofrecer agenda automática este turno y
  # resolver la pregunta por KBase primero (docs/vault-tickets Pendiente.md, punto 1/3a).
  attr_reader :pending_technical_question, :technical_question

  # Con outcome == :linked_existing: el CaseTicket reusado. El caller (el job) lo usa
  # para NO ofrecer agenda automática cuando el caso ya existente quedó marcado como
  # `multiple_requests` (2026-09-03, conv. #113: un caso escalado por "varios servicios
  # independientes" seguía ofreciendo horarios en el siguiente turno, contradiciendo su
  # propio mensaje de escalamiento — ver Pendiente.md).
  attr_reader :linked_ticket

  # `directive:` permite pasar la directiva de UNA rama concreta (@ruta) en lugar de
  # dejar que el servicio la busque en el prompt entero. Así cada rama puede escalar a
  # su propio tipo y prioridad de ticket.
  def initialize(message, tracking:, directive: nil)
    @directive_text = directive
    @message      = message
    @tracking     = tracking
    @account      = message.account
    @conversation = message.conversation
    @contact      = message.conversation.contact
    @outcome      = :no_directive
    @spawned_trackings = []
    @pending_technical_question = false
    @technical_question = nil
  end

  def create_if_needed
    return false unless directive_present?

    # §11.2 Anti-duplicado: reusa caso abierto (o escala si ya se lo repetimos de más).
    # @crear_ticket_multiple agrega 2 outcomes que NO cortan acá: `nil` de siempre (no había
    # caso activo) y `:confirmed_new_request` (el cliente confirmó que es un caso aparte) —
    # ambos siguen al flujo normal de creación. `:technical_question` sí corta, pero
    # devolviendo `false`: el turno no lo atendió este servicio, así que el job sigue su
    # cascada normal hasta la KBase, en vez de vincularlo al caso que no tiene que ver.
    reuse_outcome = reuse_existing_ticket
    return finish(reuse_outcome, false) if reuse_outcome == :technical_question
    # 2026-09-05 (conv. #137/#139): si además el prompt tiene @disponibilidad_calendar, un
    # "nuevo confirmado" tampoco se construye acá — se corta devolviendo `false` para que el
    # job la deje resolver primero (agenda scoped al recurso), y el ticket se arme recién al
    # confirmar la cita (`create_after_appointment`), igual que la primera solicitud. Sin esa
    # directiva, sigue igual que siempre: cae al flujo normal de creación de acá abajo.
    return finish(reuse_outcome, false) if reuse_outcome == :confirmed_new_request && disponibilidad_calendar_present?
    return finish(reuse_outcome, true) if reuse_outcome && reuse_outcome != :confirmed_new_request

    # Sin @disponibilidad_calendar, un "nuevo confirmado" se construye YA (ver arriba) — acotar
    # acá el texto que va a leer el intake para que no arrastre la solicitud vieja.
    apply_new_request_conversation_scope! if reuse_outcome == :confirmed_new_request

    fields = intake_fields # nil = IA no disponible → degradar

    if fields
      @pending_technical_question = fields['pending_technical_question'] == true
      @technical_question = fields['technical_question']

      # §2 (mínimo urgente): si son 2+ solicitudes independientes, NO las resumamos en
      # un solo ticket perdiendo la mitad — se arma un ticket con TODAS listadas y se
      # escala. Va ANTES que needs_escalation? (2026-09-03: reordenado — encontrado con
      # corpus real que cuando el intake marcaba las dos señales true para el mismo
      # mensaje, needs_escalation ganaba y el ticket se armaba con el resumen genérico,
      # perdiendo la segunda solicitud. Esta señal tiene manejo de datos dedicado que no
      # pierde información; debe ganar sobre la genérica. Ver Pendiente.md.)
      return finish(:escalated_multiple, true) if multiple_requests?(fields)

      # §3 (solución de fondo, recursos por ID_RECURSO): 2+ recursos nombrados para el
      # MISMO trabajo, resueltos contra el catálogo real — un ContactTracking/ticket por
      # recurso, cada uno con su propia cita. Si no se resuelven TODOS, escala en vez de
      # adivinar o mezclar los recursos en un ticket genérico. Mismo motivo que arriba:
      # va antes que needs_escalation? para no perder el detalle de cada recurso.
      resources_outcome = resources_requested(fields)
      return finish(resources_outcome, true) if resources_outcome

      # §1: la política de negocio (complementary_prompt) marcó esta solicitud como algo
      # que debe pasar directo a un humano — independiente de si amerita ticket o no.
      # Corta el turno ACÁ, nunca llega a KBase ni al fallback conversacional. Va
      # DESPUÉS de §2/§3 para que esas señales, más específicas y con manejo de datos
      # propio, tengan prioridad cuando ambas se disparan para el mismo mensaje.
      return finish(:escalated, true) if needs_escalation?(fields)

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

  # @tickets_cases (plan @disponibilidad_calendar, Fase 3, 2026-09-04) — crea el ticket
  # DESPUÉS de que el cliente ya eligió horario y la cita quedó confirmada, con el
  # recurso/calendario ya resueltos por @disponibilidad_calendar — invierte el orden de
  # siempre (ticket antes de la agenda) solo para las cuentas que usan esa directiva. El
  # caller (el job, en `confirm_and_create_appointment`) decide cuándo invocarlo y nunca
  # lo hace si ya existe un ticket activo para el contacto.
  def create_after_appointment(id_recurso:, calendar_id:)
    return false unless directive_present?

    apply_new_request_conversation_scope!
    fields = intake_fields
    # El flujo normal llama esto vía request_missing_fields ANTES de build_ticket (deja
    # @field_values listo para intake_custom_attributes). Acá no tiene sentido "pedir" lo
    # que falte — la cita ya se confirmó — pero si NO se llama, @field_values queda vacío y
    # el ticket sale sin material/ubicaciones/peso (bug encontrado en conv. #132: el ticket
    # se creaba bien, pero sin ninguno de los campos obligatorios del tipo de caso).
    resolve_type_and_fields(fields)
    ticket = build_ticket(directive_overrides, fields)
    return false unless ticket

    ticket.update!(custom_attributes: ticket.custom_attributes.merge('id_recurso' => id_recurso,
                                                                     'calendar_id' => calendar_id))
    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    send_confirmation(ticket)
    @outcome = :created
    true
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error creando ticket post-agenda: #{e.message}"
    false
  end

  private

  # Registra el outcome de create_if_needed y devuelve `result` (azúcar para poder
  # usarlo en un `return` de una sola línea).
  def finish(outcome, result)
    @outcome = outcome
    result
  end

  # §11.2 Anti-duplicado: si ya hay un caso abierto del contacto, lo reusa y avisa.
  # Guard anti-loop: si ya se lo dijimos MAX_LINKED_REPEATS veces seguidas sin que el
  # contacto pida mover/cancelar ni nada que el flujo normal resuelva, escala en vez de
  # repetir el mismo texto para siempre. Devuelve el outcome (:linked_existing,
  # :escalated_repeat, o con @crear_ticket_multiple también :technical_question/
  # :asked_new_request_confirmation/:confirmed_new_request), o nil si no hay caso activo.
  def reuse_existing_ticket
    # 2026-09-05 (conv. #148) — mientras se recolectan los datos de una solicitud nueva YA
    # confirmada (puede tomar varios turnos), no hay que volver a preguntar "¿es lo mismo o es
    # nuevo?" ni vincular nada al caso viejo — se trata este tramo de la conversación como si no
    # hubiera ningún caso activo, hasta que el ticket nuevo se cree (o expire la marca).
    return nil if new_request_in_progress?

    existing = orchestrator.find_active_ticket
    return nil unless existing

    return reuse_existing_ticket_multiple(existing) if multiple_mode?

    if linked_repeat_limit_reached?
      escalate_linked_existing(existing)
      :escalated_repeat
    else
      register_linked_repeat
      link_and_confirm_existing(existing)
      @linked_ticket = existing
      :linked_existing
    end
  end

  # @crear_ticket_multiple (2026-09-04, docs/vault-tickets Pendiente.md) — a diferencia del
  # modo normal, un caso ya abierto NO significa "vincular ciegamente cualquier mensaje
  # siguiente": clasifica primero qué es este mensaje respecto al caso activo.
  def multiple_mode?
    directive_source.match?(MULTIPLE_DIRECTIVE_RE)
  end

  # A diferencia de `multiple_mode?` (mira `directive_source`, que puede ser una rama), esto
  # mira el prompt COMPLETO — @disponibilidad_calendar es una directiva aparte, no un parámetro
  # de @crear_ticket, así que puede estar en otra parte del prompt.
  def disponibilidad_calendar_present?
    @tracking&.complementary_prompt.to_s.match?(/@disponibilidad_calendar\b/i)
  end

  def reuse_existing_ticket_multiple(existing)
    return resolve_new_request_confirmation(existing) if awaiting_new_request_confirmation?

    case classify_reuse(existing)
    when 'technical_question'
      :technical_question
    when 'new_request'
      ask_new_request_confirmation(existing)
      :asked_new_request_confirmation
    else # 'same_case' o clasificación fallida (ver classify_reuse) — nunca por defecto crea
      link_and_confirm_existing(existing)
      @linked_ticket = existing
      :linked_existing
    end
  end

  def classify_reuse(existing)
    Cases::Ai::TicketReuseClassifier.new(account: @account)
                                    .classify(conversation_text: conversation_text,
                                              active_ticket_summary: ticket_summary(existing))
  rescue StandardError => e
    Rails.logger.warn "[TicketCreator] ⚠️ classify_reuse falló: #{e.message}"
    'same_case'
  end

  def ticket_summary(ticket)
    "#{ticket.title} — #{ticket.description.to_s.truncate(200)}"
  end

  def new_request_confirm_key
    self.class.new_request_confirm_key(@conversation.id)
  end

  def awaiting_new_request_confirmation?
    Redis::Alfred.get(new_request_confirm_key).present?
  end

  def new_request_in_progress?
    Redis::Alfred.get(self.class.new_request_in_progress_key(@conversation.id)).present?
  end

  def ask_new_request_confirmation(existing)
    Redis::Alfred.setex(new_request_confirm_key, '1', NEW_REQUEST_CONFIRM_TTL)
    # 2026-09-05 (docs/vault-tickets Pendiente.md, rough edge) — recuerda desde qué mensaje
    # arranca la solicitud nueva, para que el ticket que se arme (acá o en
    # `create_after_appointment`, un turno después) describa SOLO esta solicitud — sin esto, el
    # intake compartido lee las últimas 8 conversaciones, ve la solicitud VIEJA todavía ahí, y a
    # veces la mezcla de nuevo en la descripción del caso nuevo (duplicándola).
    Redis::Alfred.setex(self.class.new_request_source_message_key(@conversation.id), @message.id.to_s,
                        NEW_REQUEST_CONFIRM_TTL)
    folio = existing.folio.presence || "##{existing.id}"
    deliver("Veo que ya tienes el caso #{folio} en curso. ¿Esto que me cuentas es parte de ese " \
            'mismo caso, o es un servicio nuevo y aparte? Si es nuevo, decímelo y lo registro por separado.')
  end

  # Solo crea un caso aparte con una confirmación EXPLÍCITA del cliente (nunca "porque sí") —
  # ante cualquier respuesta ambigua, `confirm_new_request?` devuelve false y se vincula al
  # caso existente (comportamiento seguro por defecto, no duplica sin estar seguro).
  def resolve_new_request_confirmation(existing)
    Redis::Alfred.delete(new_request_confirm_key)

    if Cases::Ai::TicketReuseClassifier.new(account: @account).confirm_new_request?(@message.content.to_s)
      # No confirma acá: si hay @disponibilidad_calendar, el ticket se arma un turno después
      # (`create_after_appointment`) y es ESA llamada la que necesita el texto acotado — dejamos
      # la marca puesta (con su propio TTL) en vez de consumirla ahora.
      # 2026-09-05 (conv. #148) — si además puede tomar VARIOS turnos (disponibilidad no siempre
      # resuelve al primer intento), deja puesta la marca "en curso" para que ningún turno
      # intermedio vuelva a preguntar "¿es lo mismo o es nuevo?" — se borra recién al crear el
      # ticket nuevo (`create_after_appointment`) o expira sola.
      Redis::Alfred.setex(self.class.new_request_in_progress_key(@conversation.id), '1', NEW_REQUEST_CONFIRM_TTL) if disponibilidad_calendar_present?
      :confirmed_new_request
    else
      Redis::Alfred.delete(self.class.new_request_source_message_key(@conversation.id))
      link_and_confirm_existing(existing)
      @linked_ticket = existing
      :linked_existing
    end
  end

  # Si hay una solicitud nueva confirmada pendiente de construir (ver `ask_new_request_confirmation`),
  # acota `conversation_text` a los mensajes DESDE esa solicitud en adelante — evita que el intake
  # vea también la solicitud anterior (ya en su propio ticket) y la mezcle en la descripción/campos
  # del caso nuevo. Sin marca pendiente, no hace nada (deja el conversation_text de siempre).
  def apply_new_request_conversation_scope!
    key = self.class.new_request_source_message_key(@conversation.id)
    since_id = Redis::Alfred.get(key)
    return if since_id.blank?

    Redis::Alfred.delete(key)
    scoped = Message.where(conversation_id: @conversation.id, message_type: %i[incoming outgoing])
                    .where('id >= ?', since_id.to_i)
                    .reorder(created_at: :asc)
                    .map { |m| "#{m.incoming? ? 'Cliente' : 'Bot'}: #{m.content.to_s.strip.truncate(200)}" }
                    .join("\n")
    @conversation_text = scoped if scoped.present?
  end

  def linked_repeat_key
    self.class.linked_repeat_key(@conversation.id)
  end

  def linked_repeat_limit_reached?
    Redis::Alfred.get(linked_repeat_key).to_i >= MAX_LINKED_REPEATS
  end

  def register_linked_repeat
    count = Redis::Alfred.get(linked_repeat_key).to_i + 1
    Redis::Alfred.setex(linked_repeat_key, count.to_s, PENDING_TTL)
  end

  # Reutiliza send_escalation_confirmation (mismo mensaje fijo de handoff que usa §1) para
  # que un escalamiento se vea siempre igual, sea por política de negocio o por este guard.
  def escalate_linked_existing(ticket)
    Redis::Alfred.delete(linked_repeat_key)
    ticket.update(conversation: @conversation) if ticket.conversation_id.nil?
    send_escalation_confirmation(ticket, 'el contacto insiste y el caso no avanza')
  end

  # Construye el ticket (con campos capturados), aplica reglas y confirma al cliente.
  def create_and_confirm(fields)
    ticket = build_ticket(directive_overrides, fields)
    return false unless ticket

    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    send_confirmation(ticket)
    true
  end

  # Texto sobre el que se lee la directiva: la de la rama si se pasó, o el prompt entero.
  def directive_source
    @directive_text.presence || @tracking&.complementary_prompt.to_s
  end

  def directive_present?
    directive_source.match?(DIRECTIVE_RE)
  end

  # true si la conversación NO amerita ticket (cierra el ciclo de Fase 2 si lo hubo).
  def not_ticket_worthy?(fields)
    return false unless fields['ticket_worthy'] == false

    Redis::Alfred.delete(pending_key)
    true
  end

  # §1 — la política de negocio del prompt (policy_prompt) marcó que esto debe escalar.
  # Corta el turno acá: no crea ticket por el camino normal, no sigue a @agendar_calendar,
  # no llega a KBase ni al conversacional. El mensaje de hand-off es fijo/templado (no lo
  # redacta el LLM) para que un escalamiento siempre se vea igual de claro.
  def needs_escalation?(fields)
    return false unless fields['needs_escalation']

    handle_escalation(fields)
    true
  end

  # Reusa build_ticket (mismo intake, mismos datos) para no perder lo ya extraído — solo
  # cambia la confirmación al cliente y el outcome.
  def handle_escalation(fields)
    ticket = build_ticket(directive_overrides, fields)
    return unless ticket

    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    send_escalation_confirmation(ticket, fields['escalation_reason'])
  end

  def send_escalation_confirmation(ticket, reason)
    Redis::Alfred.delete(pending_key)
    folio = ticket.folio.presence || "##{ticket.id}"
    motivo = reason.present? ? " (#{reason})" : ''
    text = "Esto lo tiene que atender un asesor directamente#{motivo}. Registré tu caso #{folio} " \
           'y te contactarán en breve.'
    deliver(text)

    ticket.case_events.create!(
      account: @account, event_type: :message_sent, origin: :bot,
      payload: { content: text, ticket_id: ticket.id }
    )
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error enviando confirmación de escalamiento: #{e.message}"
  end

  # §2 (mínimo urgente) — 2+ solicitudes independientes en la misma conversación.
  # No pasa por request_missing_fields (pensado para UN servicio): arma el ticket con
  # todas las solicitudes listadas y escala, en vez de intentar resumir a una sola y
  # perder las demás en silencio.
  def multiple_requests?(fields)
    return false unless fields['multiple_requests']

    handle_multiple_requests(fields)
    true
  end

  def handle_multiple_requests(fields)
    ticket = build_multiple_requests_ticket(fields)
    return unless ticket

    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    send_multiple_requests_confirmation(ticket)
  end

  def build_multiple_requests_ticket(fields)
    orchestrator.create_from_ai(
      message: @message,
      tracking: @tracking,
      title: 'Solicitud con varios servicios independientes',
      description: multiple_requests_description(fields),
      priority: 'high',
      case_type_id: resolve_case_type_id(directive_overrides, fields),
      custom_attributes: { 'multiple_requests' => true },
      force_priority: true
    )
  end

  def multiple_requests_description(fields)
    summary = Array(fields['requests_summary'])
    return fields['description'].presence || conversation_text.truncate(1000) if summary.blank?

    summary.each_with_index.map { |request, i| "#{i + 1}. #{request}" }.join("\n")
  end

  # ---------------------------------------------------------------------------
  # §3 (solución de fondo) — recursos distintos del catálogo para el mismo trabajo.
  # Devuelve :split_by_resource (todo resuelto, ya creado), :escalated_multiple (no se
  # pudo resolver todo, se escaló) o nil (no aplica — sigue el flujo normal de un solo
  # ticket, ya sea porque no se nombró ningún recurso concreto o porque era UNO solo y
  # `scope_tracking_to_single_resource` ya hizo lo que tenía que hacer).
  # ---------------------------------------------------------------------------
  def resources_requested(fields)
    descriptions = Array(fields['resources_requested'])
    return nil if descriptions.blank?

    matches = Cases::Ai::ResourceMatcher.new(account: @account, tracking: @tracking).match(descriptions)
    return scope_tracking_to_single_resource(matches.first) if descriptions.size == 1

    if matches.present? && matches.all? { |m| m[:id_recurso].present? && m[:calendar_id].present? }
      handle_resolved_resources(matches, fields)
      :split_by_resource
    else
      handle_unresolved_resources(descriptions, matches, fields)
      :escalated_multiple
    end
  end

  # 2b (docs/vault-tickets Pendiente.md) — UN solo recurso nombrado, a diferencia de §3 no
  # amerita split de ticket ni ContactTracking hijo (no hay nada que separar). Si el catálogo
  # lo resuelve, acota `booking_calendar_ids` del tracking ACTUAL a solo el calendario de ESE
  # recurso — el mismo mecanismo que ya usa `spawn_resource_tracking`/`booking_calendars_for`,
  # así que el resto del turno (creación del ticket, oferta de horarios) sigue el camino normal
  # pero ya ofrece SOLO la agenda de ese recurso en vez del pool genérico. Si NO se resuelve
  # (no encontrado en el catálogo, o la cuenta no tiene catálogo de recursos), a diferencia de
  # §3 no escala — no hay dato que se pierda por seguir el comportamiento de siempre (pool
  # genérico), así que simplemente no hace nada y el turno sigue como si esto no hubiese
  # aplicado. Siempre devuelve nil: nunca corta el turno, solo tiene el side-effect del calendario.
  def scope_tracking_to_single_resource(match)
    return nil unless single_resource_resolved?(match)

    integration_id = tracking_integration_id
    return nil unless integration_id

    @tracking.update!(booking_calendar_ids: { integration_id.to_s => [match[:calendar_id]] })
    Rails.logger.info "[TicketCreator] 🔧 Recurso único resuelto (#{match[:id_recurso]}) → calendario acotado a ese recurso"
    nil
  end

  def single_resource_resolved?(match)
    match && match[:id_recurso].present? && match[:calendar_id].present?
  end

  def tracking_integration_id
    (@tracking.tracking_template&.calendar_integration_ids.presence || @tracking.calendar_integration_ids)&.first
  end

  # Un ContactTracking + un ticket por recurso resuelto, cada uno agendando SOLO en el
  # calendario de ESE recurso (booking_calendar_ids acotado). El job (caller) ofrece la
  # disponibilidad de cada tracking hijo en el mismo turno vía `spawned_trackings`.
  def handle_resolved_resources(matches, fields)
    tickets = matches.map { |match| create_ticket_for_resource(match, fields) }
    send_resources_confirmation(tickets)
  end

  def create_ticket_for_resource(match, fields)
    tracking = spawn_resource_tracking(match)
    ticket = Cases::OrchestratorService.new(account: @account, contact: @contact, conversation: @conversation)
                                       .create_from_ai(
                                         message: @message,
                                         tracking: tracking,
                                         title: resource_ticket_title(match, fields),
                                         description: resource_ticket_description(match, fields),
                                         case_type_id: resolve_case_type_id(directive_overrides, fields),
                                         custom_attributes: { 'id_recurso' => match[:id_recurso] }
                                       )
    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    @spawned_trackings << tracking
    { tracking: tracking, ticket: ticket, match: match }
  end

  def resource_ticket_title(match, fields)
    base = fields['title'].presence || 'Solicitud de servicio'
    "#{base} — #{match[:name] || match[:requested]}"
  end

  def resource_ticket_description(match, fields)
    detalle = "Recurso: #{match[:name] || match[:requested]} (#{match[:id_recurso]})."
    [detalle, fields['description']].compact.join("\n")
  end

  # `tracking_template.calendar_integration_ids` es la integración (cuenta de Google) de
  # siempre; lo único que cambia por recurso es a QUÉ calendario dentro de esa integración
  # se acota — vía el `booking_calendar_ids` propio del tracking (columna nueva).
  def spawn_resource_tracking(match)
    integration_id = tracking_integration_id
    ContactTracking.create!(
      account: @account, contact: @contact, conversation: @conversation, inbox_id: @tracking.inbox_id,
      objective: @tracking.objective, ai_context: @tracking.ai_context,
      complementary_prompt: @tracking.complementary_prompt,
      scheduled_for: 1.minute.from_now, max_attempts: 1,
      retry_interval_value: @tracking.retry_interval_value, retry_interval_unit: @tracking.retry_interval_unit,
      keyword_actions: [],
      calendar_integration_ids: @tracking.tracking_template&.calendar_integration_ids.presence || @tracking.calendar_integration_ids,
      calendar_event_duration: @tracking.tracking_template&.calendar_event_duration || @tracking.calendar_event_duration,
      tracking_template_id: @tracking.tracking_template_id,
      booking_calendar_ids: { integration_id.to_s => [match[:calendar_id]] },
      parent_contact_tracking_id: @tracking.id,
      status: 'active'
    )
  end

  def send_resources_confirmation(tickets)
    Redis::Alfred.delete(pending_key)
    lineas = tickets.map { |t| "• #{t[:match][:name] || t[:match][:requested]}: caso #{t[:ticket].folio.presence || "##{t[:ticket].id}"}" }
    text = "Registré cada recurso como un caso independiente:\n#{lineas.join("\n")}\n" \
           'En un momento te comparto la disponibilidad de cada uno.'
    deliver(text)
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error enviando confirmación de recursos: #{e.message}"
  end

  # No se pudo confirmar todos los recursos contra el catálogo (no encontrado ≠ no existe:
  # no afirmamos que no exista, escalamos). Arma un ticket con lo pedido + lo que sí se
  # pudo emparejar, para que un asesor lo complete.
  def handle_unresolved_resources(descriptions, matches, fields)
    ticket = build_unresolved_resources_ticket(descriptions, matches, fields)
    return unless ticket

    Cases::RuleEngineService.new(ticket, trigger_message: @message).evaluate!
    reason = 'no pude confirmar en el catálogo todos los recursos que pediste'
    send_escalation_confirmation(ticket, reason)
  end

  def build_unresolved_resources_ticket(descriptions, matches, fields)
    lineas = descriptions.each_with_index.map do |desc, i|
      match = matches[i]
      estado = match && match[:id_recurso].present? ? "identificado como #{match[:id_recurso]}" : 'no encontrado en el catálogo'
      "#{i + 1}. #{desc} — #{estado}"
    end

    orchestrator.create_from_ai(
      message: @message,
      tracking: @tracking,
      title: 'Solicitud con varios recursos — no se pudieron confirmar todos en el catálogo',
      description: lineas.join("\n"),
      priority: 'high',
      case_type_id: resolve_case_type_id(directive_overrides, fields),
      custom_attributes: { 'resources_requested' => descriptions },
      force_priority: true
    )
  end

  def send_multiple_requests_confirmation(ticket)
    Redis::Alfred.delete(pending_key)
    folio = ticket.folio.presence || "##{ticket.id}"
    text  = 'Detecté que se trata de varios servicios independientes; los registré todos en el ' \
            "caso #{folio} para que un asesor los separe y atienda cada uno. Te contactará en breve."
    deliver(text)

    ticket.case_events.create!(
      account: @account, event_type: :message_sent, origin: :bot,
      payload: { content: text, ticket_id: ticket.id }
    )
  rescue StandardError => e
    Rails.logger.error "[TicketCreator] Error enviando confirmación multi-solicitud: #{e.message}"
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
    m = directive_source.match(DIRECTIVE_RE)
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
      'missing_info' => fields['missing_info'],
      'pending_technical_question' => fields['technical_question']
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
