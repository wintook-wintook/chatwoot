# CrmZeus — estados de un país (`abbreviation` = clave c_Estado del SAT en México).
#
#   GET /crm/states?country_id= · POST /crm/states · PATCH/DELETE /crm/states/:id
#
# El país se fija al crear. Borrar un estado borra sus ciudades; no se puede si alguna
# dirección usa una de ellas.
class Api::V1::Accounts::Crm::StatesController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    scope = CrmState.where(account_id: Current.account.id).includes(:country)
    params[:country_id].present? ? scope.where(country_id: params[:country_id]) : scope
  end

  def record_params
    fields = %i[name abbreviation]
    params.require(:state).permit(*(@record ? fields : [:country_id, *fields]))
  end

  def record_json(record)
    Crm::CatalogJson.state(record)
  end

  def usage_count(record)
    CrmOrganizationAddress.where(account_id: Current.account.id).joins(:city).where(crm_cities: { state_id: record.id }).count
  end

  def in_use_message(count)
    "#{used_by(count, 'dirección', 'direcciones')}; no se puede borrar"
  end
end
