# KANBAN0725-CONTROLLER
# app/controllers/api/v1/accounts/kanban_processes_controller.rb
class Api::V1::Accounts::KanbanProcessesController < Api::V1::Accounts::BaseController
  before_action :set_kanban_process, only: [:show, :update, :destroy]
  before_action :set_kanban_type_process, only: [:index, :create]
  before_action :check_authorization

  def index
    @kanban_processes = @kanban_type_process.kanban_processes.by_position
    
    # ✅ AGREGAR RENDER JSON EXPLÍCITO:
    render json: @kanban_processes.as_json(
      include: {
        kanban_type_process: {
          only: [:id, :process_name]
        }
      }
    )
  end

  def show
    render json: @kanban_process.as_json(
      include: {
        kanban_type_process: {
          only: [:id, :process_name]
        }
      }
    )
  end

  def create
    @kanban_process = @kanban_type_process.kanban_processes.build(kanban_process_params)
    @kanban_process.account = Current.account
    
    if @kanban_process.save
      render json: @kanban_process, status: :created
    else
      render json: { errors: @kanban_process.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @kanban_process.update(kanban_process_params)
      render json: @kanban_process
    else
      render json: { errors: @kanban_process.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    if @kanban_process.conversations.exists?
      render json: { error: 'Cannot delete kanban process with associated conversations' }, 
             status: :unprocessable_entity
    else
      @kanban_process.destroy
      head :no_content
    end
  end

  def reorder
    params[:kanban_processes].each_with_index do |process_data, index|
      kanban_process = Current.account.kanban_processes.find(process_data[:id])
      kanban_process.update(position: index)
    end
    
    render json: { message: 'Processes reordered successfully' }
  end

  private

  def set_kanban_process
    @kanban_process = Current.account.kanban_processes.find(params[:id])
  end

  def set_kanban_type_process
    @kanban_type_process = Current.account.kanban_type_processes.find(params[:kanban_type_process_id])
  end

  def kanban_process_params
    params.require(:kanban_process).permit(:type_process_name, :default, :is_system, :position)
  end

  def check_authorization
    authorize(KanbanProcess)
  end
end