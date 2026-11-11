# frozen_string_literal: true

# Agentes listos — lo que pasa cuando el agente decide. El embudo de contactos se mueve solo
# con estos hechos (Kanban::FunnelMover): etiqueta «interesado» → Interesado; caso comercial
# creado → Convertido; conversación resuelta → Descartado.
#
#   prospecto_calificado → etiqueta «interesado», nota con sus respuestas y, según el objetivo:
#                          pasarlo a la persona o equipo, o crear la oportunidad
#   descartar            → nota con el motivo y la conversación se resuelve
#   pasar_a_humano       → nota con el motivo y se pasa a la persona o equipo
class ReadyAgents::Outcomes
  QUALIFIED_LABEL = 'interesado'

  def initialize(session, sender:)
    @session = session
    @agent = session.ready_agent
    @conversation = session.conversation
    @sender = sender
  end

  def apply(decision, text)
    case decision
    when 'prospecto_calificado' then qualified(text)
    when 'descartar' then discarded(text)
    when 'pasar_a_humano' then handed_off(text)
    end
  rescue StandardError => e
    Rails.logger.error("[ReadyAgents::Outcomes] #{e.class}: #{e.message}")
    @session.update!(last_error: "#{decision}: #{e.message}".first(500))
  end

  # Se agendó la cita: etiqueta «interesado», nota y la conversación a quien la atiende (si no
  # tenía a nadie). El embudo pasa a «Cita». La sesión sigue activa: el cliente puede moverla.
  def appointment_booked
    meeting = @session.reload.case_meeting
    return unless meeting

    add_label
    when_text = ReadyAgents::Appointments.label(meeting.starts_at.in_time_zone(zone))
    note("Cita agendada: #{when_text} con #{meeting.organizer&.name}.\n#{answers_text}".strip)
    @conversation.update!(assignee_id: meeting.organizer_id) if @conversation.assignee_id.blank? && meeting.organizer_id
    @session.update!(outcome: "Cita #{when_text}")
    Kanban::FunnelTriggerJob.perform_later(@conversation.id, 'appointment_scheduled')
  end

  # Quien ya es cliente: su responsable fijo o, si no tiene, a quien se eligió al activar.
  def assign_client
    owner = @conversation.contact&.effective_owner_id
    assign(owner ? { user_id: owner } : { user_id: @agent.setting(:client_user_id), team_id: @agent.setting(:client_team_id) })
  end

  def note(text)
    Messages::MessageBuilder.new(@sender, @conversation,
                                 { content: "🤖 #{@agent.name}: #{text}", private: true, ai_agent: { name: @agent.name } }).perform
  end

  private

  def qualified(summary)
    add_label
    # Con citas, calificar no termina: falta que elija horario (la sesión sigue).
    return note("Prospecto calificado.\n#{[summary, answers_text].compact_blank.join("\n")}") if @agent.objective == 'appointment'

    detail = [summary, answers_text].compact_blank.join("\n")
    case @agent.objective
    when 'opportunity'
      ticket = create_opportunity(detail)
      note("Prospecto calificado. Se creó la oportunidad #{ticket.folio}.\n#{detail}")
      finish('qualified', "Oportunidad #{ticket.folio}")
    else
      note("Prospecto calificado.\n#{detail}")
      assign(handoff_target)
      finish('qualified', summary)
    end
  end

  def discarded(reason)
    note("Descartado: #{reason}")
    finish('discarded', reason)
    @conversation.update!(status: :resolved)
  end

  def handed_off(reason)
    note("Pasa a una persona: #{reason}")
    assign(handoff_target)
    finish('handed_off', reason)
  end

  def finish(status, text)
    @session.finish!(status, text)
  end

  def zone
    ActiveSupport::TimeZone[@conversation.inbox&.timezone.to_s] || Time.zone
  end

  def handoff_target
    { user_id: @agent.setting(:handoff_user_id), team_id: @agent.setting(:handoff_team_id) }
  end

  def assign(target)
    attrs = {}
    attrs[:assignee_id] = @conversation.account.users.where(id: target[:user_id]).pick(:id) if target[:user_id].present?
    attrs[:team_id] = @conversation.account.teams.where(id: target[:team_id]).pick(:id) if target[:team_id].present?
    @conversation.update!(attrs.compact) if attrs.compact.any?
  end

  def add_label
    @conversation.account.labels.find_or_create_by!(title: QUALIFIED_LABEL) { |label| label.color = '#16a34a' }
    @conversation.add_labels([QUALIFIED_LABEL])
  end

  def answers_text
    @session.answers.to_h.map { |q, a| "• #{q}: #{a}" }.join("\n")
  end

  # El caso comercial (el embudo la pasa sola a Convertido) con el responsable a quien se pasa.
  def create_opportunity(detail)
    type_id = @agent.setting(:case_type_id).presence ||
              @conversation.account.case_types.where(case_class: :commercial).order(:id).pick(:id)
    target = handoff_target
    Cases::OrchestratorService.new(account: @conversation.account, contact: @conversation.contact, conversation: @conversation)
                              .create_for_manual(title: "Prospecto: #{@conversation.contact&.name}".first(255), case_type_id: type_id,
                                                 description: detail, assignee_id: target[:user_id], team_id: target[:team_id])
  end
end
