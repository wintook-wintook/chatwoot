# KANBAN0725-CONTROLLER
# app/controllers/api/v1/accounts/kanban_type_processes_controller.rb
class Api::V1::Accounts::KanbanTypeProcessesController < Api::V1::Accounts::BaseController
  before_action :set_kanban_type_process, only: [:show, :update, :destroy]
  before_action :set_conversation, only: [:conversation_kanban_info]
  before_action :check_authorization

  def index
    @kanban_type_processes = Current.account.kanban_type_processes.includes(:kanban_processes)
    
    # ✅ AGREGAR RENDER JSON EXPLÍCITO:
    render json: @kanban_type_processes.as_json(
      include: {
        kanban_processes: {
          only: [:id, :type_process_name, :position, :default, :is_system]
        }
      }
    )
  end
  
  def conversation_kanban_info
    render json: {
      id: @conversation.id,
      display_id: @conversation.display_id,
      kanban_type_process_id: @conversation.kanban_type_process_id,
      kanban_process_id: @conversation.kanban_process_id,
      hasKanbanTypeProcess: @conversation.kanban_type_process_id.present?,
      hasKanbanProcess: @conversation.kanban_process_id.present?
    }
  end

  def show
    render json: @kanban_type_process.as_json(
      include: {
        kanban_processes: {
          only: [:id, :type_process_name, :position, :default, :is_system]
        }
      }
    )
  end

  def create
    @kanban_type_process = Current.account.kanban_type_processes.build(kanban_type_process_params)
    
    if @kanban_type_process.save
      render json: @kanban_type_process, status: :created
    else
      render json: { errors: @kanban_type_process.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @kanban_type_process.update(kanban_type_process_params)
      render json: @kanban_type_process
    else
      render json: { errors: @kanban_type_process.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    if @kanban_type_process.conversations.exists?
      render json: { error: 'Cannot delete kanban type process with associated conversations' }, 
             status: :unprocessable_entity
    else
      @kanban_type_process.destroy
      head :no_content
    end
  end

  private

  def set_conversation
    # 🔧 CORRECCIÓN: Buscar por display_id, no por id
    @conversation = Current.account.conversations.includes(:kanban_type_process, :kanban_process)
                          .find_by(display_id: params[:conversation_id])
    
    if @conversation.nil?
      render json: { error: 'Conversation not found' }, status: :not_found
      return
    end
  end
  

  def set_kanban_type_process
    @kanban_type_process = Current.account.kanban_type_processes.find(params[:id])
  end

  def kanban_type_process_params
    params.require(:kanban_type_process).permit(:process_name, :default, :is_system)
  end

  def check_authorization
    authorize(KanbanTypeProcess)
  end
end