# Plan-Trabajo-Campo R1 — el reporte de servicio que ve el cliente por su enlace
# (sin usuario): qué se hizo, fotos, materiales, horas y conformidad. Se imprime
# o se guarda como PDF desde el navegador.
class Public::ServiceReportsController < PublicController
  layout 'public_document'

  around_action :use_account_locale

  def show
    @ticket = CaseTicket.includes(:account, :contact, :assignee, :case_type).find_by!(report_token: params[:token])
    @account = @ticket.account
    @logs = @ticket.work_logs.ordered.includes(file_attachment: :blob)
    @tasks = @ticket.case_tasks.done.order(:position, :id)
  end

  private

  def use_account_locale(&)
    ticket = CaseTicket.select(:account_id).find_by(report_token: params[:token])
    locale = ticket&.account&.locale.presence || I18n.default_locale
    I18n.with_locale(locale, &)
  end
end
