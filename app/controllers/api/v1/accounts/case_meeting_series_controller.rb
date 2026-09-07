# frozen_string_literal: true

# ================================================================================
# @tickets_cases F1/F4 — Series de reuniones de un ticket (plan §3.2, §4.3, §4.5)
# ================================================================================
# POST   /api/v1/accounts/:id/case_tickets/:case_ticket_id/meeting-series
# PATCH  /api/v1/accounts/:id/case_tickets/:case_ticket_id/meeting-series/:id
# DELETE /api/v1/accounts/:id/case_tickets/:case_ticket_id/meeting-series/:id
#
# F4: al crear la serie se arma el RRULE (`RRuleBuilder`), se espeja el evento
# MAESTRO recurrente en Google y se materializa una `case_meeting` por ocurrencia
# (`SeriesService`). Si no hay espejo posible, las fechas se calculan localmente y
# las ocurrencias nacen `local_only` — la serie existe igual.
#
# `PATCH` con `truncate_at` corta la serie conservando lo ya realizado (§11.2):
# un solo aviso al cliente en vez de una cancelación por ocurrencia.
#
# Autorización idéntica a `case_tasks_controller`: scoping por `Current.account`
# y ticket cerrado = solo lectura.
# ================================================================================

class Api::V1::Accounts::CaseMeetingSeriesController < Api::V1::Accounts::BaseController
  FROZEN_MSG = 'Ticket cerrado: no se pueden modificar las series. Reábrelo si necesitas cambiarlas.'

  before_action :set_ticket
  before_action :set_series, only: %i[update destroy]
  before_action :block_if_frozen

  def create
    series = @ticket.case_meeting_series.build(series_params)
    series.account = Current.account
    series.organizer_id ||= current_user&.id
    series.sync_status = :pending # el servicio decide synced / local_only / failed

    if series.save
      # F4 — maestro en Google + una fila por ocurrencia. Va dentro del request a
      # propósito: la UI necesita devolver las reuniones ya creadas.
      meetings = Cases::Meetings::SeriesService.new(series, actor: current_user).generate!
      log_event(:meeting_scheduled, series.reload)
      render json: { case_meeting_series: series_json(series), meetings_created: meetings.size },
             status: :created
    else
      render json: { error: series.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # `truncate_at` (ISO8601) corta la serie conservando las ocurrencias hasta esa
  # fecha inclusive; el resto se cancela con UN solo aviso (§11.2).
  def update
    return truncate if params[:truncate_at].present?

    if @series.update(series_params)
      log_event(:meeting_updated, @series)
      render json: { case_meeting_series: series_json(@series) }
    else
      render json: { error: @series.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def truncate
    last_kept = Time.zone.parse(params[:truncate_at].to_s)
    return render json: { error: 'Fecha de corte inválida' }, status: :unprocessable_entity if last_kept.nil?

    dropped = Cases::Meetings::SeriesService.new(@series, actor: current_user).truncate!(last_kept)
    log_event(:meeting_cancelled, @series.reload, scope: 'all')
    render json: { case_meeting_series: series_json(@series), meetings_cancelled: dropped }
  end

  # Borrar la serie se lleva sus ocurrencias por la FK (`on_delete: :cascade`).
  # Para conservar el histórico, la UI cancela en vez de borrar (meetings#cancel
  # con `scope: 'all'`).
  def destroy
    log_event(:meeting_cancelled, @series, scope: 'all')
    @series.destroy
    head :no_content
  end

  private

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:case_ticket_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ticket no encontrado' }, status: :not_found
  end

  def set_series
    @series = @ticket.case_meeting_series.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Serie no encontrada' }, status: :not_found
  end

  def block_if_frozen
    render json: { error: FROZEN_MSG }, status: :unprocessable_entity if @ticket.frozen_for_edit?
  end

  def series_params
    permitted = params.require(:case_meeting_series).permit(
      :title, :description, :starts_at, :ends_at, :time_zone, :freq, :interval,
      :until_at, :count, :recurrence_rule, :case_task_id, :organizer_id, by_day: []
    )
    permitted[:organizer_id] = Current.account.users.where(id: permitted[:organizer_id]).pick(:id) if permitted.key?(:organizer_id)
    permitted
  end

  def log_event(event_type, series, scope: 'all')
    @ticket.case_events.create!(
      account: Current.account,
      event_type: event_type,
      origin: current_user ? :agent : :system,
      actor: current_user,
      case_task: series.case_task,
      payload: {
        series_id: series.id,
        folio: series.folio,
        title: series.title,
        starts_at: series.starts_at,
        series_sequence: series.sequence,
        scope: scope
      }
    )
  end

  def series_json(series)
    {
      id: series.id,
      sequence: series.sequence,
      folio: series.folio,
      title: series.title,
      description: series.description,
      starts_at: series.starts_at,
      ends_at: series.ends_at,
      time_zone: series.time_zone,
      created_at: series.created_at
    }.merge(recurrence_json(series))
  end

  # La regla de repetición + el estado del espejo (en F1 siempre `local_only`).
  def recurrence_json(series)
    {
      freq: series.freq,
      interval: series.interval,
      by_day: series.by_day,
      until_at: series.until_at,
      count: series.count,
      recurrence_rule: series.recurrence_rule,
      sync_status: series.sync_status,
      sync_error: series.sync_error,
      cancelled_at: series.cancelled_at,
      case_task: ref_task(series.case_task),
      organizer: ref_user(series.organizer),
      meetings_count: series.case_meetings.count
    }
  end

  def ref_user(user)
    return nil unless user

    { id: user.id, name: user.name }
  end

  def ref_task(task)
    return nil unless task

    { id: task.id, sequence: task.sequence, title: task.title }
  end
end
