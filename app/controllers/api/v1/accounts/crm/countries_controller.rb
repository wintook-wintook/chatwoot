# CrmZeus — países (con sus estados en el JSON, para el selector del formulario).
#
#   GET /crm/countries · POST /crm/countries · PATCH/DELETE /crm/countries/:id
#
# Borrar un país borra sus estados y ciudades; no se puede si alguna dirección usa
# una de sus ciudades.
class Api::V1::Accounts::Crm::CountriesController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    Current.account.crm_countries.includes(:states)
  end

  def record_params
    params.require(:country).permit(:name, :abbreviation, :iso_code, :is_default)
  end

  def record_json(record)
    Crm::CatalogJson.country(record)
  end

  def usage_count(record)
    CrmOrganizationAddress.where(account_id: Current.account.id).joins(city: :state)
                          .where(crm_states: { country_id: record.id }).count
  end

  def in_use_message(count)
    "#{used_by(count, 'dirección', 'direcciones')}; no se puede borrar"
  end
end
