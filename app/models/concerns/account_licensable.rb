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

  # El tope que impone la licencia, o nil si la licencia no limita esta cuenta.
  def license_agent_limit
    return nil unless Licenses::Enforcement.enabled?
    return nil if wintook_internal?
    return current_license.max_agents if current_license
    return 0 if account_licenses.exists?

    nil
  end
end
