# frozen_string_literal: true

# Asistente (Dali) — hace lo confirmado de propose_task_progress: el reporte de avance nace
# cerrado (cuenta ya y entra a la actividad del caso como reporte). Se incluye en
# Assistant::Executor.
module Assistant::ProgressRunner
  def run_task_progress(payload)
    task = progress_target(payload)
    minutes = progress_minutes(payload)
    TaskReport.transaction do
      report = TaskReport.build_for(task, user: @user, content: payload['notes'].to_s.strip.first(5000), minutes: minutes,
                                          progress: true)
      report.save!
      report.close!
    end
    done("Avance de «#{task.title}» reportado", task.case_ticket ? case_path(task.case_ticket) : "#{base}/tickets/tasks")
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  private

  def progress_target(payload)
    raise Assistant::Executor::Refused, 'Falta lo que se hizo.' if payload['notes'].to_s.strip.blank?

    task = @tools.progress_task(payload['id'])
    raise Assistant::Executor::Refused, Assistant::Executor::FROZEN if task.case_ticket&.frozen_for_edit?

    task
  end

  def progress_minutes(payload)
    minutes = payload['minutes'].presence&.to_i
    raise Assistant::Executor::Refused, I18n.t('task_reports.minutes_required') if TaskReport.minutes_required?(@account) && !minutes.to_i.positive?

    minutes
  end
end
