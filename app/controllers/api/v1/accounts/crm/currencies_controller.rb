# CrmZeus O1 — monedas.
#
#   GET /crm/currencies · POST /crm/currencies · PATCH/DELETE /crm/currencies/:id
class Api::V1::Accounts::Crm::CurrenciesController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    Current.account.crm_currencies
  end

  def record_params
    params.require(:currency).permit(:name, :iso_code, :symbol, :amount_in_words, :is_local, :fixed_exchange_rate,
                                     :is_default, :active)
  end

  def record_json(record)
    Crm::CatalogJson.currency(record)
  end

  def usage_column
    :currency_id
  end
end
