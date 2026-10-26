# Plan-Trabajo-Campo R1 — el reporte de servicio de una orden de trabajo.
#
# - «En campo»: la orden lo dice (`on_site`) o lo toma de su tipo.
# - Requisitos para terminarla (pasar a Terminada o Cerrada): las tareas
#   obligatorias hechas y, si el tipo lo pide, fotos de antes y después y la
#   conformidad de quien recibió. Sin eso no se termina y se dice qué falta.
# - Enlace del reporte para el cliente (`report_token`) y, si el tipo lo manda
#   solo, se envía al cliente cuando la orden se termina.
module ServiceReportable
  extend ActiveSupport::Concern

  COMPLETION_STATUSES = %w[resolved validating closed].freeze

  included do
    has_many :work_logs, class_name: 'CaseWorkLog', dependent: :destroy
    has_many :time_entries, class_name: 'CaseTimeEntry', dependent: :destroy
    # Plan-Trabajo-Campo R4 — la orden se hace sobre un equipo y puede venir de un mantenimiento.
    belongs_to :customer_asset, optional: true
    belongs_to :maintenance_plan, optional: true
  end

  def on_site_effective
    return on_site unless on_site.nil?

    case_type&.field_setting(:on_site_default) || false
  end

  # Lo que falta para terminar la orden ([] = está completa).
  def service_report_missing
    return [] unless work_order?

    missing = []
    missing << :required_tasks if case_tasks.pending.exists?(required: true)
    missing.concat(missing_photos) if type_requires?(:require_photos)
    missing << :conformity if type_requires?(:require_conformity) && received_by.blank?
    missing
  end

  def ensure_report_token!
    update_column(:report_token, SecureRandom.base58(24)) if report_token.blank? # rubocop:disable Rails/SkipsModelValidations
    report_token
  end

  private

  def type_requires?(key)
    case_type.present? && case_type.field_setting(key)
  end

  def missing_photos
    tags = work_logs.photo.distinct.pluck(:tag)
    [(:photo_before unless tags.include?('before')), (:photo_after unless tags.include?('after'))].compact
  end

  def completing?(old_status, new_status)
    work_order? && COMPLETION_STATUSES.include?(new_status.to_s) && COMPLETION_STATUSES.exclude?(old_status.to_s)
  end

  def ensure_service_report_complete!(old_status, new_status)
    return unless completing?(old_status, new_status)

    missing = service_report_missing
    return if missing.empty?

    labels = missing.map { |key| I18n.t("service_reports.missing.#{key}") }
    raise ServiceReports::Incomplete, I18n.t('service_reports.incomplete', missing: labels.to_sentence)
  end

  def deliver_report_after_completion(old_status, new_status)
    return unless completing?(old_status, new_status)
    return unless case_type&.field_setting(:report_delivery) == 'auto' && report_sent_at.nil?

    ServiceReports::Delivery.new(self, nil).deliver!
  rescue ServiceReports::Delivery::Error => e
    Rails.logger.info "[ServiceReport] #{folio}: no se envió solo (#{e.message})"
  end
end
