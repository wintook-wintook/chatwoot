# CrmZeus O1 — organizaciones (clientes y prospectos).
#
#   GET    /crm/organizations          ?type=customer|prospect &q= &status= &seller_id= &page=  (con contacts_count)
#   GET    /crm/organizations/:id      con domicilio y consignatarios
#   POST   /crm/organizations          { organization: {..., home_address_attributes: {...}} }
#   PATCH  /crm/organizations/:id
#   DELETE /crm/organizations/:id
#   POST   /crm/organizations/:id/convert   prospecto → cliente
class Api::V1::Accounts::Crm::OrganizationsController < Api::V1::Accounts::Crm::BaseController
  PER_PAGE = 50
  FIELDS = %i[organization_type key legal_name trade_name phone email tax_id customer_type_id rating_id industry_id
              origin_id zone_id collector_id seller_id respect_seller payment_term_id currency_id credit_limit status
              suspended_on suspension_reason charge_taxes withholds_taxes cfdi_use sat_payment_form invoice_email notes].freeze
  ADDRESS_FIELDS = %i[id consignee_name street exterior_number interior_number neighborhood town reference city_id
                      postal_code tax_id phone phone2 email contact_name for_billing].freeze

  before_action :check_sales_write_access, except: %i[index show]
  before_action :set_organization, except: %i[index create]

  def index
    scope = filtered
    page = [params[:page].to_i, 1].max
    render json: {
      organizations: list_items(scope, page),
      meta: { count: scope.count, page: page, per_page: PER_PAGE, counts: type_counts, can_edit: access_grant.writable?(:sales) }
    }
  end

  def show
    render json: { organization: detail_json }
  end

  def create
    @organization = organizations.new(organization_params.merge(created_by: Current.user, updated_by: Current.user))
    return render_errors(@organization) unless @organization.save

    render json: { organization: detail_json }, status: :created
  end

  def update
    return render_errors(@organization) unless @organization.update(organization_params.merge(updated_by: Current.user))

    render json: { organization: detail_json }
  end

  def destroy
    @organization.destroy!
    head :ok
  end

  def convert
    return render json: { message: 'Ya es cliente' }, status: :unprocessable_entity if @organization.customer?

    @organization.convert_to_customer!(Current.user)
    render json: { organization: detail_json }
  end

  private

  def organizations
    Current.account.crm_organizations
  end

  # Una página de la lista, con cuántos contactos tiene ligados cada organización.
  def list_items(scope, page)
    rows = scope.includes(*Crm::OrganizationJson::LIST_INCLUDES).order(:trade_name, :id)
                .offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    contacts = CrmOrganizationContact.where(organization_id: rows.map(&:id)).group(:organization_id).count
    rows.map { |org| Crm::OrganizationJson.list_item(org).merge(contacts_count: contacts[org.id].to_i) }
  end

  def filtered
    filters = { organization_type: enum_param(:type, CrmOrganization.organization_types),
                status: enum_param(:status, CrmOrganization.statuses), seller_id: params[:seller_id].presence }.compact
    organizations.search(params[:q]).where(filters)
  end

  def enum_param(name, values)
    params[name].to_s if values.key?(params[name].to_s)
  end

  # Para las pestañas Clientes / Prospectos / Todos (con la búsqueda aplicada, sin el tipo).
  def type_counts
    counts = organizations.search(params[:q]).group(:organization_type).count
    { customer: counts['customer'].to_i, prospect: counts['prospect'].to_i, all: counts.values.sum }
  end

  def set_organization
    @organization = organizations.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(*FIELDS, home_address_attributes: ADDRESS_FIELDS)
  end

  def detail_json
    Crm::OrganizationJson.detail(organizations.includes(*Crm::OrganizationJson::DETAIL_INCLUDES).find(@organization.id))
  end
end
