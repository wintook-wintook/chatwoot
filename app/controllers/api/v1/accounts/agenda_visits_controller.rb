# frozen_string_literal: true

# Visitas — la visita de una tarea agendada, sin orden de trabajo (el vendedor).
#   GET  /agenda_visits/arrivals?user_id=&from=&to=   llegadas de técnicos y vendedores
#   GET  /agenda_visits/:id
#   POST /agenda_visits/:id/on_my_way  { eta_minutes }
#   POST /agenda_visits/:id/arrive     { lat, lng, accuracy, occurred_at }
class Api::V1::Accounts::AgendaVisitsController < Api::V1::Accounts::BaseController
  before_action :set_meeting, except: :arrivals

  def show
    render_visit
  end

  def on_my_way
    Field::AgendaVisit.new(@meeting, current_user).on_my_way!(params[:eta_minutes].to_i)
    render_visit
  end

  def arrive
    Field::AgendaVisit.new(@meeting, current_user).arrive!(location_param, at: occurred_at || Time.current)
    render_visit
  end

  def arrivals
    user_id = see_all? ? params[:user_id].presence : current_user.id
    render json: { arrivals: Field::Arrivals.new(Current.account, user_id: user_id, from: date(:from), to: date(:to)&.end_of_day).rows }
  end

  private

  def set_meeting
    @meeting = Current.account.case_meetings.where(is_visit: true).find(params[:id])
    render_access_denied unless @meeting.organizer_id == current_user.id || see_all?
  end

  def see_all?
    access_grant.admin? || %w[all view].include?(access_grant.level(:agenda))
  end

  def render_visit
    render json: { visit: Field::AgendaVisitSerializer.new(@meeting.reload).as_json }
  end

  def date(key)
    Time.zone.parse(params[key].to_s) if params[key].present?
  rescue ArgumentError
    nil
  end

  def location_param
    return {} if params[:lat].blank? || params[:lng].blank?

    { lat: params[:lat].to_f, lng: params[:lng].to_f, accuracy: params[:accuracy]&.to_f, at: Time.current.iso8601 }.compact
  end

  # Sin señal el celular guarda la hora: solo de las últimas 24 horas, nunca a futuro.
  def occurred_at
    at = Time.zone.parse(params[:occurred_at].to_s) if params[:occurred_at].present?
    at if at&.between?(24.hours.ago, 1.minute.from_now)
  rescue ArgumentError
    nil
  end
end
