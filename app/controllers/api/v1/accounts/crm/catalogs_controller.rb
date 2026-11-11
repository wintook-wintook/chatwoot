# CrmZeus O1/A1 — todos los catálogos de los formularios (organizaciones y artículos) en una sola llamada.
# La primera vez que la cuenta lo pide se precargan los catálogos base (México, peso, contado).
#
#   GET /crm/catalogs   ?all=true incluye los inactivos (pantalla de catálogos); trae también los parámetros
class Api::V1::Accounts::Crm::CatalogsController < Api::V1::Accounts::Crm::BaseController
  def show
    ::Crm::DefaultCatalogs.ensure!(Current.account)
    render json: {
      lookups: lookups, sellers: sellers, payment_terms: payment_terms, currencies: currencies, countries: countries,
      statuses: CrmOrganization.statuses.keys, can_admin: access_grant.admin?,
      # Artículos (A1)
      article_lines: article_lines, units: units, taxes: taxes, tax_types: CrmTax.tax_types.keys,
      article_statuses: CrmArticle.statuses.keys,
      # Parámetros de la cuenta (Q3.1)
      settings: CrmSetting.for_account(account).as_crm_json
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

  def article_lines
    scoped(account.crm_article_lines).ordered.includes(:group).map { |item| Crm::CatalogJson.article_line(item) }
  end

  def units
    scoped(account.crm_units).ordered.map { |item| Crm::CatalogJson.unit(item) }
  end

  def taxes
    scoped(account.crm_taxes).ordered.map { |item| Crm::CatalogJson.tax(item) }
  end

  def account
    Current.account
  end
end
