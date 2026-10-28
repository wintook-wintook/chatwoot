# CrmZeus O1 — vendedores (con liga opcional a un agente de la cuenta).
#
#   GET /crm/sellers · POST /crm/sellers · PATCH/DELETE /crm/sellers/:id
class Api::V1::Accounts::Crm::SellersController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    Current.account.crm_sellers.includes(:user)
  end

  def record_params
    params.require(:seller).permit(:name, :notes, :user_id, :is_default, :active)
  end

  def record_json(record)
    Crm::CatalogJson.seller(record)
  end

  def usage_column
    :seller_id
  end
end
