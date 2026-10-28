# CrmZeus O1 — todos los catálogos del formulario de organizaciones en una sola llamada.
# La primera vez que la cuenta lo pide se precargan los catálogos base (México, peso, contado).
#
#   GET /crm/catalogs   ?all=true incluye los inactivos (pantalla de catálogos)
class Api::V1::Accounts::Crm::CatalogsController < Api::V1::Accounts::Crm::BaseController
  def show
    ::Crm::DefaultCatalogs.ensure!(Current.account)
    render json: {
      lookups: lookups, sellers: sellers, payment_terms: payment_terms, currencies: currencies, countries: countries,
      statuses: CrmOrganization.statuses.keys, can_admin: access_grant.admin?
    }
  end

  private

  def scoped(relation)
    params[:all] == 'true' ? relation : relation.active
  end

  def lookups
    grouped = scoped(account.crm_lookups).ordered.group_by(&:kind)
    CrmLookup.kinds.keys.index_with { |kind| (grouped[kind] || []).map { |item| Crm::CatalogJson.lookup(item) } }
  end

  def sellers
    scoped(account.crm_sellers).ordered.includes(:user).map { |item| Crm::CatalogJson.seller(item) }
  end

  def payment_terms
    scoped(account.crm_payment_terms).ordered.includes(:installments).map { |item| Crm::CatalogJson.payment_term(item) }
  end

  def currencies
    scoped(account.crm_currencies).ordered.map { |item| Crm::CatalogJson.currency(item) }
  end

  def countries
    account.crm_countries.ordered.includes(:states).map { |item| Crm::CatalogJson.country(item) }
  end

  def account
    Current.account
  end
end
