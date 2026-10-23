# ================================================================================
# feat/licencias (F2) — QUIÉN ENTRA A LA GESTIÓN DE LICENCIAS
# ================================================================================
# Todo lo de /api/v1/accounts/:account_id/licenses/* ve y toca TODAS las cuentas de la
# instalación, así que la puerta es doble y se valida en el servidor (§8 del plan):
#   1. la cuenta desde la que se entra está marcada «Cuenta de Wintook» en el super admin;
#   2. el usuario tiene «Ver licencias» (leer) o «Gestionar licencias» (escribir).
# Un agente con permiso que entra desde una cuenta de cliente recibe 401.
# ================================================================================
class Api::V1::Accounts::Licenses::BaseController < Api::V1::Accounts::BaseController
  before_action :check_view_permission

  private

  def check_view_permission
    head :unauthorized unless Current.account.wintook_internal? && Current.user&.can_view_licenses?
  end

  def check_manage_permission
    head :unauthorized unless Current.user&.can_manage_licenses?
  end
end
