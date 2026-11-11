# frozen_string_literal: true

# Asistente (Dali) — hace lo confirmado de propose_convert_item con Cases::Conversion. Se
# incluye en Assistant::Executor.
module Assistant::ConvertRunner
  def run_convert_item(payload)
    item = @tools.cancel_target(payload['kind'], payload['id'])
    raise Assistant::Executor::Refused, Assistant::Executor::FROZEN if item.case_ticket&.frozen_for_edit?

    service = Cases::Conversion.new(item, user: @user)
    label = payload['kind'] == 'meeting' ? converted_to_task(service, payload) : converted_to_meeting(service, payload)
    done(label, item.case_ticket ? case_path(item.case_ticket) : "#{base}/tickets/tasks")
  rescue Cases::Conversion::Error => e
    raise Assistant::Executor::Refused, e.message
  end

  private

  def converted_to_meeting(service, payload)
    result = service.to_meeting(starts_at: time(payload['starts_at']), ends_at: time(payload['ends_at']),
                                location: payload['location'], time_zone: Time.zone.name)
    meeting = result[:meeting]
    when_text = I18n.l(meeting.starts_at.in_time_zone, format: '%d/%m %H:%M')
    return "Sesión de «#{meeting.title}» agendada el #{when_text}; la tarea se queda" if result[:mode] == 'linked'

    "«#{meeting.title}» agendada el #{when_text}"
  end

  def converted_to_task(service, payload)
    result = service.to_task(notify_client: payload['notify_client'] == true)
    label = "«#{result[:task].title}» quedó como tarea"
    notice = result[:notice]
    return label if notice.nil?

    label + (notice[:sent] ? ' · se le avisó al cliente' : ' · no se le pudo avisar al cliente')
  end
end
