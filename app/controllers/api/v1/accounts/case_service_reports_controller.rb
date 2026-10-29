# Plan-Trabajo-Campo R1 — el reporte de servicio de una orden de trabajo.
#
#   GET    /case_tickets/:case_ticket_id/service_report
#   PATCH  /case_tickets/:case_ticket_id/service_report            { on_site: true|false|null }
#   POST   /case_tickets/:case_ticket_id/service_report/logs       { kind, tag, content, file }
#   DELETE /case_tickets/:case_ticket_id/service_report/logs/:id   (lo propio, o el Administrador)
#   POST   /case_tickets/:case_ticket_id/service_report/timer      { action: start|stop }
#   POST   /case_tickets/:case_ticket_id/service_report/time_entries  { started_at, ended_at | minutes, note }
#   DELETE /case_tickets/:case_ticket_id/service_report/time_entries/:id
#   POST   /case_tickets/:case_ticket_id/service_report/deliver    manda el enlace al cliente
#   POST   /case_tickets/:case_ticket_id/service_report/external_link  { name, phone } técnico externo (R5)
#   DELETE /case_tickets/:case_ticket_id/service_report/external_link  quita el enlace
class Api::V1::Accounts::CaseServiceReportsController < Api::V1::Accounts::BaseController
  before_action :set_ticket
  before_action :check_writable, except: %i[show]

  def show
    render_report
  end

  def update
    @ticket.update!(on_site: ActiveModel::Type::Boolean.new.cast(params[:on_site])) if params.key?(:on_site)
    @ticket.update!(customer_asset: contact_asset) if params.key?(:customer_asset_id) # Plan-Trabajo-Campo R4
    render_report
  end

  def create_log
    log = @ticket.work_logs.new(log_attributes)
    log.file.attach(params[:file]) if params[:file].present?
    log.save!
    render_report(:created)
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    render_error(e.respond_to?(:record) ? e.record.errors.full_messages : e.message)
  end

  # Plan-Trabajo-Campo R5 — técnico externo: enlace sin usuario que sirve hasta terminar la visita.
  def external_link
    name = params[:name].to_s.strip
    return render_error(I18n.t('field_portal.errors.name_required')) if name.blank?

    @ticket.issue_external_link!(name: name.first(120), phone: params[:phone].to_s.strip.first(30))
    render_report
  end

  def revoke_external_link
    @ticket.close_external_link!
    render_report
  end

  def destroy_log
    log = @ticket.work_logs.find(params[:id])
    return render_access_denied unless log.user_id == current_user.id || access_grant.admin?

    log.destroy!
    render_report
  end

  def timer
    running = @ticket.time_entries.running.find_by(user_id: current_user.id)
    if params[:timer_action] == 'stop'
      running&.update!(ended_at: Time.current)
    elsif running.nil?
      @ticket.time_entries.create!(account: Current.account, user: current_user, started_at: Time.current, source: :timer)
    end
    render_report
  end

  def create_time_entry
    entry = @ticket.time_entries.new(account: Current.account, user: current_user, source: :manual, note: params[:note],
                                     started_at: params[:started_at].presence || Time.current)
    apply_entry_end(entry)
    entry.save!
    render_report(:created)
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages)
  end

  def destroy_time_entry
    entry = @ticket.time_entries.find(params[:id])
    return render_access_denied unless entry.user_id == current_user.id || access_grant.admin?

    entry.destroy!
    render_report
  end

  def deliver
    ServiceReports::Delivery.new(@ticket, current_user).deliver!
    render_report
  rescue ServiceReports::Delivery::Error => e
    render_error(e.message)
  end

  private

  # Solo un equipo del mismo cliente de la orden (vacío = sin equipo).
  def contact_asset
    return if params[:customer_asset_id].blank?

    Current.account.customer_assets.find_by!(id: params[:customer_asset_id], contact_id: @ticket.contact_id)
  end

  def log_attributes
    { account: Current.account, user: current_user, kind: params[:kind].presence || 'note',
      tag: params[:tag].presence, content: params[:content] }
  end

  # Con hora de fin, o con minutos (termina «minutos» después del inicio).
  def apply_entry_end(entry)
    entry.ended_at = params[:ended_at] if params[:ended_at].present?
    entry.minutes = params[:minutes].to_i if params[:minutes].present?
    entry.ended_at ||= entry.started_at + entry.minutes.to_i.minutes
  end

  def set_ticket
    @ticket = account_case_tickets.find(params[:case_ticket_id])
    render_error(I18n.t('service_reports.errors.not_work_order')) unless @ticket.work_order?
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('service_reports.errors.not_found') }, status: :not_found
  end

  def check_writable
    render_access_denied unless access_grant.case_writable?(@ticket)
  end

  def render_report(status = :ok)
    render json: { service_report: ServiceReports::Serializer.new(@ticket.reload, user: current_user).as_json }, status: status
  end

  def render_error(message)
    render json: { error: Array(message).join(', ') }, status: :unprocessable_entity
  end
end
