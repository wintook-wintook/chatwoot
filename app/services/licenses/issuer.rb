# ================================================================================
# feat/licencias (F2) — EMITIR UNA LICENCIA DESDE LA GESTIÓN
# ================================================================================
# Lo usa quien tiene «Gestionar licencias». Parte de un plan del catálogo y copia sus valores,
# ajustables para esta cuenta (agentes, días, nombre). Dos formas de arrancar:
#
#   now    activa YA: la activa anterior (demo o de pago) queda cancelada. Si la cuenta estaba
#          suspendida se reactiva (reactivar no es automático: §11 del plan).
#   queue  pagada por adelantado: queda PROGRAMADA y arranca cuando termine la última vigente o
#          programada (F3 la promueve). Sin nada vigente, arranca ya.
#
# Los canales y funciones del plan solo se guardan en el plan; todavía no se aplican a la
# cuenta (decisión 23/10/2026, pregunta abierta 14.1).
# Plan: docs/licencias_plan_v1.md §5 y §10 (F2)
# ================================================================================
class Licenses::Issuer
  class Invalid < StandardError; end

  STARTS = %w[now queue].freeze

  pattr_initialize [:account!, :plan!, :created_by, :start, :max_agents, :duration_days, :name, :notes]

  def perform
    raise Invalid, I18n.t('licenses.errors.invalid_start') unless STARTS.include?(start_mode)

    AccountLicense.transaction do
      account.lock!
      queued? ? schedule : activate_now
    end
  end

  private

  def start_mode
    (start.presence || 'now').to_s
  end

  def queued?
    start_mode == 'queue' && account.current_license.present?
  end

  def activate_now
    account.current_license&.update!(status: :cancelled)
    licencia = build(:active, Time.current)
    licencia.save!
    account.update!(status: :active) if account.suspended?
    licencia
  end

  def schedule
    inicio = [account.current_license.expires_at, account.account_licenses.scheduled.maximum(:expires_at)].compact.max
    licencia = build(:scheduled, inicio || Time.current)
    licencia.save!
    licencia
  end

  def build(status, inicio)
    dias = (duration_days.presence || plan.duration_days).to_i
    account.account_licenses.new(
      license_plan: plan, created_by: created_by, status: status,
      name: name.presence || plan.name, license_type: plan.license_type,
      max_agents: (max_agents.presence || plan.default_max_agents).to_i, duration_days: dias,
      starts_at: inicio, expires_at: inicio + dias.days, notes: notes.presence,
      metadata: { 'source' => 'manual' }
    )
  end
end
