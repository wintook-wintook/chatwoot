# CrmZeus O1 — tipo de cliente, calificación, giro, origen, zona y cobrador.
#
#   GET /crm/lookups?kind=rating · POST /crm/lookups · PATCH/DELETE /crm/lookups/:id
class Api::V1::Accounts::Crm::LookupsController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    scope = Current.account.crm_lookups
    CrmLookup.kinds.key?(params[:kind].to_s) ? scope.where(kind: params[:kind]) : scope
  end

  # El catálogo (kind) se fija al crear: cambiarlo dejaría organizaciones apuntando al equivocado.
  def record_params
    fields = %i[name is_default position active]
    params.require(:lookup).permit(*(@record ? fields : [:kind, *fields]))
  end

  def record_json(record)
    Crm::CatalogJson.lookup(record)
  end

  def usage_column
    "#{@record.kind}_id"
  end
end
