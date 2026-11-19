# frozen_string_literal: true

# «Atención a clientes» — lo que pasa cuando el agente decide (Motor2::Outcomes lo llama):
#   handoff (canalizar o pasar_a_humano) → nota con el área y el motivo; la conversación se asigna a
#                                          quien eligió la empresa para esa área (o al general) y el agente se pausa
#   done                                 → el seguimiento termina
# Los casos y oportunidades ya se crearon en el turno (Motor2::Skills::AreaActions), con su responsable.
class Motor2::Functions::CustomerOutcomes
  def initialize(tracking, conversation, function)
    @tracking = tracking
    @conversation = conversation
    @function = function
    @template = tracking.tracking_template
  end

  def apply(kind, text)
    case kind
    when 'handoff' then handed_off(text)
    when 'done' then @tracking.mark_objective_met!
    end
  rescue StandardError => e
    Rails.logger.error("[Motor2::CustomerOutcomes] #{e.class}: #{e.message}")
    @tracking.update_columns(last_error: "#{kind}: #{e.message}".first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def booked(meeting)
    when_text = Motor2::Skills::Appointments.label(meeting.starts_at.in_time_zone(@function.config.zone))
    note("Cita agendada: #{when_text} con #{meeting.organizer&.name}.")
    @conversation.update!(assignee_id: meeting.organizer_id) if @conversation.assignee_id.blank? && meeting.organizer_id
  end

  # «Solo clientes» y quien escribe no lo es: se pasa a una persona con un saludo y el agente no lo atiende.
  def turn_away!
    target = @function.handoff_target
    assign(target)
    who = @conversation.reload.assignee&.name.to_s.split.first
    Motor2::Delivery.send_reply(@tracking, @conversation,
                                "¡Hola! Te comunico con #{who.presence || 'alguien de nuestro equipo'}, en un momento te escribe.")
    note('No es cliente: se pasó a una persona.')
    @tracking.mark_objective_met!
    @tracking.update_columns(outcome: 'not_client', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def note(text)
    Motor2::Delivery.note(@tracking, @conversation, "🤖 #{@template.name}: #{text}")
  end

  private

  def handed_off(reason)
    area = @tracking.motor2_state.to_h['handoff_area']
    title = @function.area(area)&.dig('title')
    note(["Pasa a una persona#{" (#{title})" if title}: #{reason}", pending_text].compact_blank.join("\n"))
    assign(@function.handoff_target(area))
    @tracking.update_columns(outcome: "handed_off#{": #{title}" if title}".first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.pause!
  end

  # Lo que también pidió y no se alcanzó a atender: que la persona lo vea.
  def pending_text
    queue = Array(@tracking.motor2_state.to_h['cola'])
    return '' if queue.empty?

    "También pidió: #{queue.pluck('intencion').join(' · ')}"
  end

  def assign(target)
    attrs = {}
    attrs[:assignee_id] = @conversation.account.users.where(id: target[:user_id]).pick(:id) if target[:user_id].present?
    attrs[:team_id] = @conversation.account.teams.where(id: target[:team_id]).pick(:id) if target[:team_id].present?
    @conversation.update!(attrs.compact) if attrs.compact.any?
  end
end
