# ================================================================================
# feat/licencias (F1) — LA DEMO DE UNA CUENTA NUEVA
# ================================================================================
# Al registrarse una cuenta (AccountBuilder) se le emite una licencia copiando el plan marcado
# de registro (LicensePlan.signup_default_plan): nombre, tipo, agentes y días.
#
# Se emite aunque el interruptor general esté apagado (decisión 23/10/2026): mientras esté
# apagado no limita nada, pero la cuenta ya nace con su vencimiento y al encenderlo no hay que
# asignarle nada a mano.
#
# Nunca tumba un registro: sin plan de registro, o si algo falla, la cuenta nace sin licencia
# (fuera de licencia, como hoy) y queda en el log. Va en su propio savepoint para que un error
# aquí no aborte la transacción del registro. Una cuenta que ya tiene licencias no recibe otra.
# Plan: docs/licencias_plan_v1.md §5 y §10 (F1)
# ================================================================================
class Licenses::DemoIssuer
  pattr_initialize [:account!, :created_by]

  def perform
    plan = LicensePlan.signup_default_plan
    return if plan.nil? || account.account_licenses.exists?

    AccountLicense.transaction(requires_new: true) { issue(plan) }
  rescue StandardError => e
    Rails.logger.error("[LICENSES] demo no emitida para la cuenta #{account.id}: #{e.class} #{e.message}")
    nil
  end

  private

  def issue(plan)
    inicio = Time.current
    account.account_licenses.create!(
      license_plan: plan, created_by: created_by, status: :active,
      name: plan.name, license_type: plan.license_type,
      max_agents: plan.default_max_agents, duration_days: plan.duration_days,
      starts_at: inicio, expires_at: inicio + plan.duration_days.days,
      metadata: { 'source' => 'signup' }
    )
  end
end
