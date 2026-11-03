# Plan-Trabajo-Campo R2 — portal del técnico (web para celular).
#
#   GET  /field_visits?day=YYYY-MM-DD   sus visitas del día (órdenes en campo, suyas, con visita)
#   GET  /field_visits/history?from=&to=   «Mis trabajos»: sus órdenes terminadas en el periodo
#   GET  /field_visits/:id              una orden para la pantalla de visita
#   POST /field_visits/:id/on_my_way    { eta_minutes }  «Voy en camino» al cliente por WhatsApp
#   POST /field_visits/:id/arrive       { lat, lng, accuracy }  empieza la visita (horas + ubicación)
#   POST /field_visits/:id/finish       { lat, lng, received_by, conformity_note, signature }
#                                       termina la visita y la orden (si cumple los requisitos)
#   POST /field_visits/:id/send_to_technician   (oficina) le manda al técnico el enlace de la visita
#
# R5: arrive y finish aceptan `occurred_at` (la hora en que pasó, si el celular estaba sin señal).
#
# Todo pasa por los casos que el rol deja ver (el técnico: los suyos).
class Api::V1::Accounts::FieldVisitsController < Api::V1::Accounts::BaseController
  before_action :set_order, except: %i[index history]
  before_action :check_writable, except: %i[index history show]

  def index
    day = parse_day
    render json: { day: day, visits: Field::Route.new(account_case_tickets, current_user, day, user_zone).visits }
  end

  def history
    to = parse_day(:to)
    from = parse_day(:from, to.beginning_of_month)
    from = to - 1.year if from < to - 1.year
    render json: Field::WorkHistory.new(account_case_tickets, current_user, [from, to].min, to).as_json
  end

  def show
    render json: { visit: Field::VisitSerializer.new(@order, current_user).as_json }
  end

  def on_my_way
    Field::Messages.new(@order, current_user).on_my_way!(params[:eta_minutes].to_i)
    render json: { visit: Field::VisitSerializer.new(@order.reload, current_user).as_json }
  rescue Field::Messages::Error => e
    render_error(e.message)
  end

  def arrive
    Field::Visit.new(@order, current_user, at: occurred_at).arrive!(location_param)
    render json: { visit: Field::VisitSerializer.new(@order.reload, current_user).as_json }
  end

  def finish
    Field::Visit.new(@order, current_user, at: occurred_at).finish!(location_param, conformity_params)
    render json: { visit: Field::VisitSerializer.new(@order.reload, current_user).as_json }
  rescue ServiceReports::Incomplete, RuntimeError, ActiveRecord::RecordInvalid => e
    render_error(e.message)
  end

  def send_to_technician
    Field::Messages.new(@order, current_user).to_technician!
    head :ok
  rescue Field::Messages::Error => e
    render_error(e.message)
  end

  private

  def set_order
    @order = account_case_tickets.find(params[:id])
    render_error(I18n.t('service_reports.errors.not_work_order')) unless @order.work_order?
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('service_reports.errors.not_found') }, status: :not_found
  end

  def check_writable
    render_access_denied unless access_grant.case_writable?(@order)
  end

  def user_zone
    ActiveSupport::TimeZone[params[:tz].to_s] || Time.zone
  end

  def parse_day(key = :day, fallback = Time.zone.today)
    Date.parse(params[key].to_s)
  rescue Date::Error
    fallback
  end

  # Plan-Trabajo-Campo R5 — sin señal el celular guarda la hora y la manda después;
  # solo se acepta de las últimas 24 horas y nunca en el futuro.
  def occurred_at
    at = Time.zone.parse(params[:occurred_at].to_s) if params[:occurred_at].present?
    at if at&.between?(24.hours.ago, 1.minute.from_now)
  rescue ArgumentError
    nil
  end

  def location_param
    return {} if params[:lat].blank? || params[:lng].blank?

    { lat: params[:lat].to_f, lng: params[:lng].to_f, accuracy: params[:accuracy]&.to_f, at: Time.current.iso8601 }.compact
  end

  def conformity_params
    data = params.permit(:received_by, :conformity_note, :signature).to_h.symbolize_keys
    data[:signature] = nil unless data[:signature].to_s.start_with?('data:image/png;base64,') && data[:signature].size < 400_000
    data
  end

  def render_error(message)
    render json: { error: Array(message).join(', ') }, status: :unprocessable_entity
  end
end
