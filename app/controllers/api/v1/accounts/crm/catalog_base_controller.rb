# CrmZeus O1 — alta, cambio y baja de un catálogo de organizaciones (solo Administrador).
# Lo que una organización ya usa no se borra: se desactiva (como CRMZeus/Microsip).
# Cada catálogo define `relation`, `record_params`, `record_json` y `usage_column`.
class Api::V1::Accounts::Crm::CatalogBaseController < Api::V1::Accounts::Crm::BaseController
  before_action :check_admin_access, except: %i[index]
  before_action :set_record, only: %i[update destroy]

  def index
    render json: { items: relation.ordered.map { |record| record_json(record) } }
  end

  def create
    record = relation.new(record_params)
    return render_errors(record) unless record.save

    render json: { item: record_json(record) }, status: :created
  end

  def update
    return render_errors(@record) unless @record.update(record_params)

    render json: { item: record_json(@record) }
  end

  def destroy
    in_use = usage_count(@record)
    if in_use.positive?
      return render json: { message: "Lo usan #{in_use} organizaciones; desactívalo en lugar de borrarlo" },
                    status: :unprocessable_entity
    end

    @record.destroy!
    head :ok
  end

  private

  def set_record
    @record = relation.find(params[:id])
  end

  def usage_count(record)
    Current.account.crm_organizations.where(usage_column => record.id).count
  end
end
