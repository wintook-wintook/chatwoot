# CrmZeus O1 — consignatarios de una organización (todas sus direcciones menos el
# domicilio, que se edita con la organización).
#
#   GET    /crm/organizations/:organization_id/consignees
#   POST   /crm/organizations/:organization_id/consignees      { consignee: {...} }
#   PATCH  /crm/organizations/:organization_id/consignees/:id
#   DELETE /crm/organizations/:organization_id/consignees/:id
class Api::V1::Accounts::Crm::ConsigneesController < Api::V1::Accounts::Crm::BaseController
  FIELDS = (Api::V1::Accounts::Crm::OrganizationsController::ADDRESS_FIELDS - [:id]).freeze

  before_action :check_sales_write_access, except: %i[index]
  before_action :set_organization
  before_action :set_consignee, only: %i[update destroy]

  def index
    render json: { consignees: consignees.includes(city: { state: :country }).map { |item| Crm::OrganizationJson.address(item) } }
  end

  def create
    consignee = consignees.new(consignee_params)
    return render_errors(consignee) unless consignee.save

    render json: { consignee: Crm::OrganizationJson.address(consignee) }, status: :created
  end

  def update
    return render_errors(@consignee) unless @consignee.update(consignee_params)

    render json: { consignee: Crm::OrganizationJson.address(@consignee) }
  end

  def destroy
    @consignee.destroy!
    head :ok
  end

  private

  def set_organization
    @organization = Current.account.crm_organizations.find(params[:organization_id])
  end

  def consignees
    @organization.consignees
  end

  def set_consignee
    @consignee = consignees.find(params[:id])
  end

  def consignee_params
    params.require(:consignee).permit(*FIELDS)
  end
end
