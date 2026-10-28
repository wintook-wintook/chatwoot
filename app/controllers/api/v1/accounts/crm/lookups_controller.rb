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

  # Listas de precios y grupos de líneas se usan en artículos, no en organizaciones.
  def usage_count(record)
    return CrmArticlePrice.where(account_id: record.account_id, price_list_id: record.id).count if record.price_list?
    return CrmArticleLine.where(account_id: record.account_id, group_id: record.id).count if record.line_group?

    super
  end

  def in_use_message(count)
    return "#{used_by(count, 'precio de artículo', 'precios de artículos')}; desactívala en lugar de borrarla" if @record.price_list?
    return "#{used_by(count, 'línea', 'líneas')}; desactívalo en lugar de borrarlo" if @record.line_group?

    super
  end
end
