# CrmZeus A1 — unidades de venta (con clave SAT opcional).
#
#   GET /crm/units · POST /crm/units · PATCH/DELETE /crm/units/:id
class Api::V1::Accounts::Crm::UnitsController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    Current.account.crm_units
  end

  def record_params
    params.require(:unit).permit(:name, :sat_key, :is_default, :active)
  end

  def record_json(record)
    Crm::CatalogJson.unit(record)
  end

  def usage_count(record)
    Current.account.crm_articles.where(unit_id: record.id).count
  end

  def in_use_message(count)
    "#{used_by(count, 'artículo', 'artículos')}; desactívala en lugar de borrarla"
  end
end
