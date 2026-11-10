# frozen_string_literal: true

# Asistente (Dali) — cancela lo confirmado con Cases::Cancellation (motivo, tiempo, serie no:
# solo esta; aviso al cliente si se pidió). Se incluye en Assistant::Executor.
module Assistant::CancelRunner
  def run_cancel_item(payload)
    item = @tools.cancel_target(payload['kind'], payload['id'])
    raise Assistant::Executor::Refused, Assistant::Executor::FROZEN if item.case_ticket&.frozen_for_edit?

    result = Cases::Cancellation.new(item, user: @user, params: payload.slice('reason_id', 'comment', 'minutes', 'notify_client')).call
    path = item.case_ticket ? case_path(item.case_ticket) : "#{base}/tickets/tasks"
    done(cancel_label(item, result[:notice]), path)
  rescue Cases::Cancellation::Error => e
    raise Assistant::Executor::Refused, e.message
  end

  private

  def cancel_label(item, notice)
    label = "Cancelada «#{item.title}»"
    return label if notice.nil?

    label + (notice[:sent] ? ' · se le avisó al cliente' : ' · no se le pudo avisar al cliente')
  end
end
