# frozen_string_literal: true

# «Atención a prospectos» — lo que pasa cuando el agente decide (viene de ReadyAgents::Outcomes).
# El embudo de contactos se mueve solo con estos hechos (Kanban::FunnelMover): etiqueta
# «interesado» → Interesado; caso comercial creado → Convertido; conversación resuelta → Descartado.
#
#   qualified (prospecto_calificado) → etiqueta «interesado», nota con sus respuestas y, según el
#                                      objetivo: pasarlo, crear la oportunidad o (con citas) seguir
#   discarded (descartar)            → nota con el motivo y la conversación se resuelve
#   handoff   (pasar_a_humano)       → nota con el motivo y sus respuestas y se pasa a la persona o equipo
#   booked (se agendó la cita)       → etiqueta, nota, se asigna a quien la atiende y el embudo pasa a «Cita»
#   client! (ya es cliente)          → lo pasa a su responsable sin atenderlo como prospecto
# Al pasarlo a una persona (calificado o pasar_a_humano) arranca el reloj de atención (attend_hours): si nadie le
# escribe a tiempo, TrackingCampaigns::HandoffSweepJob avisa al vendedor y luego escala a los administradores.
# Con temperatura (caliente, tibio, frío) queda la etiqueta «prospecto-caliente»… y va en la nota.
class Motor2::Functions::ProspectOutcomes
  QUALIFIED_LABEL = 'interesado'
  TEMPERATURE_LABELS = { 'caliente' => ['prospecto-caliente', '#dc2626'], 'tibio' => ['prospecto-tibio', '#f59e0b'],
                         'frio' => ['prospecto-frio', '#3b82f6'] }.freeze
  TEMPERATURE_TEXT = { 'caliente' => '🔥 caliente', 'tibio' => '🌤 tibio', 'frio' => '❄️ frío' }.freeze

  def initialize(tracking, conversation, function)
    @tracking = tracking
    @conversation = conversation
    @function = function
    @template = tracking.tracking_template
  end

  def apply(kind, text)
    add_temperature_label if temperature
    Motor2::ProspectRecord.save(@conversation.contact, @template, state)
    case kind
    when 'qualified' then qualified(text)
    when 'discarded' then discarded(text)
    when 'handoff' then handed_off(text)
    when 'done' then finish('qualified', text)
    end
  rescue StandardError => e
    Rails.logger.error("[Motor2::ProspectOutcomes] #{e.class}: #{e.message}")
    @tracking.update_columns(last_error: "#{kind}: #{e.message}".first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # Se agendó la cita: etiqueta «interesado», nota y la conversación a quien la atiende (si no
  # tenía a nadie). El embudo pasa a «Cita». El seguimiento sigue: el cliente puede moverla.
  def booked(meeting)
    add_label
    Motor2::ProspectRecord.save(@conversation.contact, @template, state)
    when_text = Motor2::Skills::Appointments.label(meeting.starts_at.in_time_zone(@function.config.zone))
    note("Cita agendada: #{when_text} con #{meeting.organizer&.name}.\n#{answers_text}".strip)
    @conversation.update!(assignee_id: meeting.organizer_id) if @conversation.assignee_id.blank? && meeting.organizer_id
    @tracking.update_columns(outcome: "Cita #{when_text}".first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    Kanban::FunnelTriggerJob.perform_later(@conversation.id, 'appointment_scheduled')
  end

  # Quien ya es cliente: le contesta una vez («te comunico con Ana»), se lo pasa a su responsable
  # fijo (o a quien se eligió en el asistente), deja una nota y se hace a un lado. No entra al embudo.
  def client!
    owner = @conversation.contact&.effective_owner_id
    assign(owner ? { user_id: owner } : @function.client_target)
    who = @conversation.reload.assignee&.name
    Motor2::Delivery.send_reply(@tracking, @conversation, Motor2::VoiceText.call(@function.config, greeting(who)))
    org = @conversation.contact&.organization
    note("Es cliente#{" (#{org.name})" if org}: se pasó a #{who || 'una persona del equipo'}.")
    @tracking.mark_objective_met!
    @tracking.update_columns(outcome: 'client', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # Motor2::InboxRouter: no le toca atenderlo.
  def turn_away! = client!

  def note(text)
    Motor2::Delivery.note(@tracking, @conversation, "🤖 #{@template.name}: #{text}")
  end

  private

  def state = @tracking.motor2_state.to_h

  def temperature = state['temperature'].presence_in(TEMPERATURE_LABELS.keys)

  def qualified(summary)
    add_label
    detail = [summary, answers_text].compact_blank.join("\n")
    return quoted(detail) if state['quote'] # pidió la cotización: ya trae su oportunidad
    # Con citas, calificar no termina: falta que elija horario (el seguimiento sigue).
    return note("Prospecto calificado.\n#{detail}") if @function.appointment?

    if @function.objective == 'opportunity'
      ticket = create_opportunity(detail)
      note("Prospecto calificado. Se creó la oportunidad #{ticket.folio}.\n#{detail}")
      finish('qualified', "Oportunidad #{ticket.folio}")
    else
      note("Prospecto calificado.\n#{detail}")
      assign(@function.handoff_target)
      Motor2::AttendClock.start(@tracking, @conversation, @function)
      finish('qualified', summary)
    end
  end

  # Lo calificó la cotización (Motor2::Skills::Quote): al vendedor, sin abrir otra oportunidad (la cotización ya la tiene).
  def quoted(detail)
    note("Prospecto calificado: pidió la cotización #{state.dig('quote', 'folio')}.\n#{detail}")
    assign(@function.handoff_target)
    Motor2::AttendClock.start(@tracking, @conversation, @function)
    finish('qualified', "Cotización #{state.dig('quote', 'folio')}")
  end

  def discarded(reason)
    note("Descartado: #{reason}")
    @tracking.update_columns(outcome: 'discarded', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.cancel!
    @conversation.update!(status: :resolved)
  end

  # Pasa a una persona: el agente se pausa (se puede reanudar desde la conversación).
  def handed_off(reason)
    note(["Pasa a una persona: #{reason}", answers_text].compact_blank.join("\n"))
    assign(@function.handoff_target)
    Motor2::AttendClock.start(@tracking, @conversation, @function)
    @tracking.update_columns(outcome: 'handed_off', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.pause!
  end

  # mark_objective_met! deja outcome «objective_met»: el resultado de la función va después.
  def finish(outcome, text)
    @tracking.mark_objective_met!
    @tracking.update_columns(outcome: [outcome, text].compact_blank.join(': ').first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def assign(target)
    attrs = {}
    attrs[:assignee_id] = @conversation.account.users.where(id: target[:user_id]).pick(:id) if target[:user_id].present?
    attrs[:team_id] = @conversation.account.teams.where(id: target[:team_id]).pick(:id) if target[:team_id].present?
    @conversation.update!(attrs.compact) if attrs.compact.any?
  end

  # Con las etiquetas recién leídas: al agendar y calificar en el mismo turno, una no borra a la otra.
  def add_label
    @conversation.account.labels.find_or_create_by!(title: QUALIFIED_LABEL) { |label| label.color = '#16a34a' }
    @conversation.reload.add_labels([QUALIFIED_LABEL])
  end

  def answers_text
    lines = state['answers'].to_h.map { |q, a| "• #{q}: #{a}" }
    lines.unshift("Temperatura: #{TEMPERATURE_TEXT[temperature]}") if temperature
    lines.join("\n")
  end

  # Solo una temperatura a la vez: la nueva reemplaza a la anterior.
  def add_temperature_label
    title, color = TEMPERATURE_LABELS[temperature]
    @conversation.account.labels.find_or_create_by!(title: title) { |label| label.color = color }
    others = TEMPERATURE_LABELS.values.map(&:first) - [title]
    @conversation.reload.update_labels((@conversation.label_list - others) | [title])
  end

  # El caso comercial (el embudo la pasa sola a Convertido) con el responsable a quien se pasa.
  def create_opportunity(detail)
    type_id = @function.answer(:case_type_id).presence ||
              @conversation.account.case_types.where(case_class: :commercial).order(:id).pick(:id)
    target = @function.handoff_target
    Cases::OrchestratorService.new(account: @conversation.account, contact: @conversation.contact, conversation: @conversation)
                              .create_for_manual(title: "Prospecto: #{@conversation.contact&.name}".first(255), case_type_id: type_id,
                                                 description: detail, assignee_id: target[:user_id], team_id: target[:team_id])
  end

  def greeting(who)
    name = @conversation.contact&.name.to_s.split.first
    hello = name.present? ? "¡Hola #{name}!" : '¡Hola!'
    with = who.present? ? "con #{who.split.first}" : 'con alguien de nuestro equipo'
    inbox = @conversation.inbox
    off = inbox.respond_to?(:out_of_office?) && inbox.out_of_office?
    "#{hello} Te comunico #{with}, #{off ? 'te escribe en cuanto abramos' : 'en un momento te escribe'}."
  end
end
