# CrmZeus A1 — impuestos (IVA, exento, retenciones de IVA e ISR, IEPS).
#
#   GET /crm/taxes · POST /crm/taxes · PATCH/DELETE /crm/taxes/:id
class Api::V1::Accounts::Crm::TaxesController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    Current.account.crm_taxes
  end

  def record_params
    params.require(:tax).permit(:name, :tax_type, :percent, :is_default, :active)
  end

  def record_json(record)
    Crm::CatalogJson.tax(record)
  end

  def usage_count(record)
    CrmArticleTax.where(account_id: Current.account.id, tax_id: record.id).count
  end

  def in_use_message(count)
    "#{used_by(count, 'artículo', 'artículos')}; desactívalo en lugar de borrarlo"
  end
end
