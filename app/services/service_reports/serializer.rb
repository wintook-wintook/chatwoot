# Plan-Trabajo-Campo R1 — el reporte de servicio de una orden para la pantalla:
# checklist (tareas), bitácora (notas, fotos y archivos), horas, qué falta para
# terminarla y las opciones de su tipo.
class ServiceReports::Serializer
  include Rails.application.routes.url_helpers

  def initialize(ticket, user:)
    @ticket = ticket
    @user = user
  end

  def as_json(*)
    {
      on_site: @ticket.on_site_effective, on_site_override: @ticket.on_site,
      settings: @ticket.case_type&.field_settings_effective || CaseType::FIELD_DEFAULTS,
      checklist: checklist, logs: logs, time_entries: time_entries,
      running_entry: running_entry, actual_hours: @ticket.actual_hours&.to_f,
      missing: @ticket.service_report_missing, report_sent_at: @ticket.report_sent_at,
      public_url: ServiceReports::Delivery.public_url(@ticket)
    }.merge(asset_json).merge(portal_json)
  end

  # Plan-Trabajo-Campo R5 — portal del cliente (respuesta de la visita y calificación) y técnico externo.
  def portal_json
    external = @ticket.external_technician.presence
    {
      portal_url: Field::Messages.portal_url(@ticket), visit_response: @ticket.visit_response_current.presence,
      csat: @ticket.csat_rating && { rating: @ticket.csat_rating, comment: @ticket.csat_comment, at: @ticket.csat_at },
      external: external&.merge(active: @ticket.external_link_active?, expires_at: @ticket.external_token_expires_at,
                                url: (self.class.external_url(@ticket) if @ticket.external_link_active?))
    }
  end

  def self.external_url(ticket)
    "#{ENV.fetch('FRONTEND_URL', '')}/tecnico/#{ticket.external_token}"
  end

  # Plan-Trabajo-Campo R4 — el equipo de la orden, los del cliente y el mantenimiento de origen.
  def asset_json
    asset = @ticket.customer_asset
    plan = @ticket.maintenance_plan
    {
      customer_asset: asset && { id: asset.id, name: asset.name, brand: asset.brand, model: asset.model,
                                 serial: asset.serial, location: asset.location },
      contact_assets: @ticket.contact ? @ticket.contact.customer_assets.active.ordered.map { |a| { id: a.id, name: a.name } } : [],
      maintenance_plan: plan && { id: plan.id, title: plan.title }
    }
  end

  def self.file_url(log)
    return unless log.file.attached?

    Rails.application.routes.url_helpers.rails_blob_url(log.file, only_path: true)
  end

  private

  def checklist
    @ticket.case_tasks.order(:position, :id).map do |task|
      { id: task.id, title: task.title, required: task.required, status: task.status, completed_at: task.completed_at }
    end
  end

  def logs
    @ticket.work_logs.ordered.includes(:user, file_attachment: :blob).map do |log|
      { id: log.id, kind: log.kind, tag: log.tag, content: log.content, created_at: log.created_at,
        user: log.user && { id: log.user.id, name: log.user.name }, mine: log.user_id == @user&.id,
        file_url: self.class.file_url(log), file_name: log.file.attached? ? log.file.filename.to_s : nil }
    end
  end

  def time_entries
    @ticket.time_entries.ordered.includes(:user).map { |entry| entry_json(entry) }
  end

  def running_entry
    entry = @ticket.time_entries.running.find_by(user_id: @user&.id)
    entry && entry_json(entry)
  end

  def entry_json(entry)
    { id: entry.id, started_at: entry.started_at, ended_at: entry.ended_at, minutes: entry.minutes,
      source: entry.source, note: entry.note, user: entry.user && { id: entry.user.id, name: entry.user.name },
      mine: entry.user_id == @user&.id }
  end
end
