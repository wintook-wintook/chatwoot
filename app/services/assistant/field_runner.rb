# frozen_string_literal: true

# Asistente (Dali) — hace lo confirmado del trabajo en campo con las mismas piezas que el
# portal: Field::Messages / Field::AgendaVisit para «Voy en camino»; la bitácora y la lista
# de la orden; el reporte de cierre (TaskReport) para la visita agendada, que al quedar
# «realizada» se cierra solo (TaskReportable). Se incluye en Assistant::Executor.
module Assistant::FieldRunner
  def run_on_my_way(payload)
    target = @tools.field_target(payload)
    minutes = payload['eta_minutes'].to_i
    if target[:kind] == 'order'
      Field::Messages.new(target[:record], @user).on_my_way!(minutes, zone: @zone)
    else
      Field::AgendaVisit.new(target[:record], @user).on_my_way!(minutes, zone: @zone)
    end
    done("Aviso de «voy en camino» a #{target[:client] || target[:label]}", field_path(target))
  rescue ArgumentError, Field::Messages::Error => e
    raise Assistant::Executor::Refused, e.message
  end

  def run_visit_report(payload)
    notes = payload['notes'].to_s.strip
    raise Assistant::Executor::Refused, 'Falta lo que se hizo en la visita.' if notes.blank?

    target = @tools.field_target(payload)
    target[:kind] == 'order' ? order_visit_report(target, notes, payload) : agenda_visit_report(target, notes, payload)
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  private

  def order_visit_report(target, notes, payload)
    order = target[:record]
    raise Assistant::Executor::Refused, Assistant::Executor::FROZEN if order.frozen_for_edit?

    tasks = order.case_tasks.where(id: Array(payload['done_task_ids']).map(&:to_i)).where.not(status: :done)
    CaseWorkLog.transaction do
      order.work_logs.create!(account: @account, user: @user, kind: :note, content: notes)
      tasks.each { |task| task.update!(status: :done) }
    end
    label = "Reporte en #{order.folio}#{" · #{tasks.size} punto(s) de la lista" if tasks.any?}"
    done(label, field_path(target))
  end

  def agenda_visit_report(target, notes, payload)
    meeting = target[:record]
    raise Assistant::Executor::Refused, 'Esa visita ya está concluida.' if meeting.concluded?

    minutes = payload['minutes'].presence&.to_i
    raise Assistant::Executor::Refused, I18n.t('task_reports.minutes_required') if TaskReport.minutes_required?(@account) && !minutes.to_i.positive?

    TaskReport.transaction do
      meeting.task_reports.pending_close.destroy_all
      TaskReport.build_for(meeting, user: @user, content: notes.first(5000), minutes: minutes).save!
      meeting.update!(status: :held)
    end
    done("Visita «#{meeting.title}» reportada y realizada", field_path(target))
  end

  def field_path(target)
    target[:kind] == 'order' ? "#{base}/campo/visita/#{target[:id]}" : "#{base}/campo/cita/#{target[:id]}"
  end
end
