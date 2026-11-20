# frozen_string_literal: true

# «Vendedor de campaña» — lo que pasa cuando el agente decide (Motor2::Outcomes lo llama):
#   relay     (le_interesa)             → Motor2::Relay: al agente que sigue o a una persona
#   discarded (no_le_interesa)          → nota con el motivo; el seguimiento se cierra (no más toques)
#   done      (confirmó / no va / terminó la encuesta) → nota y cumplido; encuesta con calificación baja → caso
#   handoff   (pasar_a_humano)          → nota, se asigna a la persona o equipo y el agente se pausa
#   booked    (agendó la cita)          → nota, se asigna a quien la atiende y cumplido
class Motor2::Functions::CampaignSellerOutcomes
  def initialize(tracking, conversation, function)
    @tracking = tracking
    @conversation = conversation
    @function = function
    @template = tracking.tracking_template
  end

  def apply(kind, text)
    case kind
    when 'relay' then Motor2::Relay.new(@tracking, @conversation, @function).call(text)
    when 'discarded' then discarded(text)
    when 'done' then done(text)
    when 'handoff' then handed_off(text)
    end
  rescue StandardError => e
    Rails.logger.error("[Motor2::CampaignSellerOutcomes] #{e.class}: #{e.message}")
    @tracking.update_columns(last_error: "#{kind}: #{e.message}".first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def booked(meeting)
    when_text = Motor2::Skills::Appointments.label(meeting.starts_at.in_time_zone(@function.config.zone))
    note("Le interesó y agendó: #{when_text} con #{meeting.organizer&.name}.")
    @conversation.update!(assignee_id: meeting.organizer_id) if @conversation.assignee_id.blank? && meeting.organizer_id
    finish("Cita #{when_text}")
  end

  def note(text)
    Motor2::Delivery.note(@tracking, @conversation, "🤖 #{@template.name}: #{text}")
  end

  private

  def state = @tracking.motor2_state.to_h

  def discarded(reason)
    note("No le interesa: #{reason}")
    # El motivo queda en su memoria para «En qué se van» de la Campaña con Vendedor IA (Motor2CampaignResults).
    @tracking.update_columns(outcome: 'discarded', motor2_state: state.merge('exit_reason' => reason.to_s.first(200)), # rubocop:disable Rails/SkipsModelValidations
                             updated_at: Time.current)
    @tracking.cancel!
  end

  def done(text)
    return survey_done if @function.survey?

    note(text)
    finish(text)
  end

  # Las respuestas en la nota; con una calificación baja, un caso para que alguien lo atienda.
  def survey_done
    answers = @function.survey_questions.each_with_index.map do |q, i|
      saved = state.dig('survey', (i + 1).to_s).to_h
      "• #{q}: #{saved['respuesta'] || '—'}"
    end
    low = low_scores
    note(["Contestó la encuesta#{' — calificación baja' if low.any?}:", *answers].join("\n"))
    ticket = low.any? ? low_score_case(answers) : nil
    finish(ticket ? "Encuesta baja: caso #{ticket.try(:folio) || ticket.id}" : 'Encuesta contestada')
  end

  def low_scores
    state['survey'].to_h.values.filter_map { |v| v['calificacion'] }.map(&:to_i).select { |n| n < @function.low_score }
  end

  def low_score_case(answers)
    type_id = @conversation.account.case_types.active.where(case_class: :support).order(:id).pick(:id)
    target = @function.handoff_target
    Cases::OrchestratorService.new(account: @conversation.account, contact: @conversation.contact, conversation: @conversation)
                              .create_for_manual(title: "Encuesta con calificación baja: #{@conversation.contact&.name}".first(200),
                                                 description: answers.join("\n"), case_type_id: type_id, priority: 'high',
                                                 assignee_id: target[:user_id], team_id: target[:team_id])
  end

  def handed_off(reason)
    note("Pasa a una persona: #{reason}")
    assign(@function.handoff_target)
    Motor2::AttendClock.start(@tracking, @conversation, @function)
    @tracking.update_columns(outcome: 'handed_off', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.pause!
  end

  def finish(text)
    @tracking.mark_objective_met!
    @tracking.update_columns(outcome: text.to_s.first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def assign(target)
    attrs = {}
    attrs[:assignee_id] = @conversation.account.users.where(id: target[:user_id]).pick(:id) if target[:user_id].present?
    attrs[:team_id] = @conversation.account.teams.where(id: target[:team_id]).pick(:id) if target[:team_id].present?
    @conversation.update!(attrs.compact) if attrs.compact.any?
  end
end
