# CrmZeus O1 — condiciones de pago con sus plazos (installments_attributes, con _destroy).
#
#   GET /crm/payment_terms · POST /crm/payment_terms · PATCH/DELETE /crm/payment_terms/:id
class Api::V1::Accounts::Crm::PaymentTermsController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    Current.account.crm_payment_terms.includes(:installments)
  end

  def record_params
    params.require(:payment_term).permit(:name, :early_payment_discount_percent, :early_payment_days, :is_default, :active,
                                         installments_attributes: %i[id days percent position _destroy])
  end

  def record_json(record)
    Crm::CatalogJson.payment_term(record)
  end

  def usage_column
    :payment_term_id
  end
end
