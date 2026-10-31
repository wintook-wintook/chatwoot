# La orden de trabajo cierra con su reporte de servicio: al terminar la visita deja también
# su línea en Reportes y en las fichas del cliente, igual que una tarea concluida.
class Field::VisitReport
  def initialize(order, entry, user)
    @order = order
    @entry = entry
    @user = user
  end

  def record!
    return if @entry && TaskReport.exists?(case_time_entry_id: @entry.id)

    # El texto se guarda: va en el idioma de la cuenta, no en el de quien lo dispare.
    I18n.with_locale(@order.account.locale) { create_report }
  end

  private

  def create_report
    finished_at = @entry&.ended_at || Time.current
    TaskReport.create!(account_id: @order.account_id, case_ticket: @order, contact: @order.contact, organization: @order.organization,
                       user: @user, case_time_entry: @entry, title: @order.title, content: content,
                       outcome_label: I18n.t('task_reports.visit_done'), closed_at: finished_at, created_at: finished_at)
  end

  def content
    received = I18n.t('task_reports.received_by', name: @order.received_by) if @order.received_by.present?
    [@order.conformity_note, received].compact_blank.join("\n").presence || I18n.t('task_reports.visit_done')
  end
end
