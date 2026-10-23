# ================================================================================
# feat/licencias (F3) — AVISOS ANTES DE VENCER
# ================================================================================
# Lo corre Licenses::ReminderJob una vez al día. A los administradores de la cuenta, por
# correo, cuando a su licencia activa le quedan 10 días o menos y luego 5 o menos. Cada aviso
# una sola vez por licencia (reminded_at["10"] / ["5"]).
#
# Solo con el interruptor encendido (apagado no vence nada, no tiene sentido avisar), nunca a
# una «Cuenta de Wintook», y no si ya tiene un periodo en cola (no se le va a cortar).
# El banner en el dashboard llega en F5.
# Plan: docs/licencias_plan_v1.md §5
# ================================================================================
class Licenses::ReminderService
  THRESHOLDS = [5, 10].freeze

  def initialize(now: Time.current)
    @now = now
  end

  def perform
    return unless Licenses::Enforcement.enabled?

    AccountLicense.active.where(expires_at: @now..(@now + THRESHOLDS.max.days)).includes(:account).find_each { |l| remind(l) }
  end

  private

  def remind(licencia)
    cuenta = licencia.account
    return if cuenta.wintook_internal? || cuenta.account_licenses.scheduled.exists?

    dias = ((licencia.expires_at - @now) / 1.day).ceil
    umbral = THRESHOLDS.find { |t| dias <= t }
    return if umbral.nil? || licencia.reminded_at[umbral.to_s].present?

    AdministratorNotifications::LicenseNotificationsMailer.with(account: cuenta).expiring(licencia, dias).deliver_later
    licencia.update!(reminded_at: licencia.reminded_at.merge(umbral.to_s => @now.iso8601))
  end
end
