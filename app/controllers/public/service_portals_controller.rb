# Plan-Trabajo-Campo R5 — el portal del cliente para su orden de trabajo (sin
# usuario, con el mismo enlace del reporte): en qué va, cuándo es la visita y
# quién va; confirmar o pedir otra fecha; el reporte y las cotizaciones de la
# orden; y, ya terminada, calificar el servicio.
class Public::ServicePortalsController < PublicController
  layout 'public_document'

  before_action :set_ticket
  around_action :use_account_locale

  def show
    @visit = @ticket.next_visit
    @response = @ticket.visit_response_current
    @quotes = @ticket.origin_quotes.where.not(status: :draft).order(created_at: :desc)
    @on_my_way_at = @ticket.case_events.where("payload ->> 'field' = 'on_my_way'").maximum(:created_at)
  end

  def visit
    status = params[:response].to_s
    if FieldPortal::VISIT_RESPONSES.include?(status) && !@ticket.completed_for_portal?
      @ticket.respond_to_visit!(status, note: params[:note].to_s.strip.first(500),
                                        preferred: params[:preferred].to_s.strip.first(120))
    end
    redirect_to public_service_portal_path(params[:token])
  end

  def rate
    @ticket.rate_service!(params[:rating], params[:comment].to_s.strip.first(1000)) if valid_rating?
    redirect_to params[:back] == 'report' ? public_service_report_path(params[:token]) : public_service_portal_path(params[:token])
  end

  private

  def set_ticket
    @ticket = CaseTicket.includes(:account, :contact, :assignee).find_by!(report_token: params[:token])
    @account = @ticket.account
  end

  def valid_rating?
    @ticket.rateable? && (1..5).cover?(params[:rating].to_i)
  end

  def use_account_locale(&)
    I18n.with_locale(@account.locale.presence || I18n.default_locale, &)
  end
end
