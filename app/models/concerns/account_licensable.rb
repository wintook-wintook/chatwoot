# ================================================================================
# feat/licencias (F0) — LA LICENCIA DE UNA CUENTA, VISTA DESDE ACCOUNT
# ================================================================================
# El tope de agentes ya existe en Chatwoot (AgentsController#validate_limit → 402 leyendo
# usage_limits[:agents]); esto solo le da el número correcto:
#
#   interruptor apagado          → nil  (como hoy: manda lo de siempre)
#   cuenta de Wintook            → nil  (nunca se limita ni se suspende)
#   sin ninguna licencia         → nil  (FUERA DE LICENCIA: como hoy)
#   con licencia activa          → su max_agents
#   tuvo licencia, ninguna activa → 0   (vencida: no admite agentes nuevos)
#
# Nunca expulsa a nadie: los agentes que ya están se quedan aunque pasen del tope.
# Plan: docs/licencias_plan_v1.md §6 y §8
# ================================================================================
module AccountLicensable
  extend ActiveSupport::Concern

  included do
    has_many :account_licenses, dependent: :destroy
    has_one :current_license, -> { where(status: :active) }, class_name: 'AccountLicense', inverse_of: :account, dependent: nil
  end

  # «Cuenta de Wintook» en el super admin: ahí aparece el dashboard de licencias y nunca se suspende.
  def wintook_internal?
    ActiveModel::Type::Boolean.new.cast(custom_attributes&.dig('wintook_internal')) || false
  end
  alias wintook_internal wintook_internal?

  def wintook_internal=(value)
    self.custom_attributes = (custom_attributes || {}).merge('wintook_internal' => ActiveModel::Type::Boolean.new.cast(value) || false)
  end

  # F5: tuvo licencia y ninguna está activa (la pantalla de cuenta suspendida lo distingue).
  def license_expired?
    current_license.nil? && account_licenses.exists?
  end

  # F5: lo que la propia cuenta ve de su licencia (Configuración › Licencia y el aviso del
  # dashboard). nil = fuera de licencia: no se le muestra nada.
  def license_summary
    return nil unless current_license || account_licenses.exists?

    licencia = current_license
    siguiente = account_licenses.scheduled.order(:starts_at, :id).first
    { state: licencia ? licencia.license_type : 'vencida', agents_count: users.count,
      current: licencia && license_period(licencia), next: siguiente && license_period(siguiente) }
  end

  # El tope que impone la licencia, o nil si la licencia no limita esta cuenta.
  def license_agent_limit
    return nil unless Licenses::Enforcement.enabled?
    return nil if wintook_internal?
    return current_license.max_agents if current_license
    return 0 if account_licenses.exists?

    nil
  end

  private

  def license_period(licencia)
    dias = licencia.expires_at && ((licencia.expires_at - Time.current) / 1.day).ceil
    { name: licencia.name, license_type: licencia.license_type, max_agents: licencia.max_agents,
      starts_at: licencia.starts_at, expires_at: licencia.expires_at, days_left: dias }
  end
end
