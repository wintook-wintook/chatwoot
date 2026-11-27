# CrmZeus O1 — base de la API de CrmZeus (/api/v1/accounts/:id/crm/...).
#
# Sin feature flag (los 63 bits de feature_flags están ocupados): entra quien tiene el
# área de Ventas. Todos ven todas las organizaciones (aunque su nivel sea «solo las mías»);
# escribe quien tiene Ventas con escritura; los catálogos los administra el Administrador.
class Api::V1::Accounts::Crm::BaseController < Api::V1::Accounts::BaseController
  before_action :check_sales_access

  private

  def check_sales_access
    render_access_denied unless access_grant.allowed?(:sales)
  end

  def check_sales_write_access
    render_access_denied unless access_grant.writable?(:sales)
  end

  def check_admin_access
    render_access_denied unless access_grant.admin?
  end

  def render_errors(record)
    render json: { message: record.errors.full_messages.join(', '), attributes: record.errors.attribute_names },
           status: :unprocessable_entity
  end
end
