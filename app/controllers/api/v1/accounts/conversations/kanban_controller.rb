# KANBAN0725-CONTROLLER
class Api::V1::Accounts::Conversations::KanbanController < Api::V1::Accounts::BaseController
    # NO usar before_action :check_authorization por ahora
    # El BaseController ya maneja la autenticación básica
  
    def filter_by_kanban_type
      conversations = build_conversations_query
      conversations = conversations.where(kanban_type_process_id: params[:kanban_type_process_id]) if params[:kanban_type_process_id].present?
      render_response(conversations)
    end
  
    def filter_by_kanban_process
      conversations = build_conversations_query
      conversations = conversations.where(kanban_process_id: params[:kanban_process_id]) if params[:kanban_process_id].present?
      render_response(conversations)
    end
  
    def filter_by_both_kanban
      conversations = build_conversations_query
      conversations = apply_kanban_filters(conversations)
      render_response(conversations)
    end
  
    private
  
    def build_conversations_query
      Current.account.conversations.includes(:account, :assignee, :contact, :inbox)
    end
  
    def apply_kanban_filters(conversations)
      conversations = conversations.where(kanban_type_process_id: params[:kanban_type_process_id]) if params[:kanban_type_process_id].present?
      conversations = conversations.where(kanban_process_id: params[:kanban_process_id]) if params[:kanban_process_id].present?
      conversations = conversations.where(status: params[:status]) if params[:status].present?
      conversations = conversations.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
      conversations
    end
  
    def render_response(conversations)
      render json: {
        data: conversations.map(&:push_event_data),
        meta: {
          count: conversations.count,
          current_page: 1,
          filters_applied: {
            kanban_type_process_id: params[:kanban_type_process_id],
            kanban_process_id: params[:kanban_process_id],
            status: params[:status],
            assignee_id: params[:assignee_id]
          }
        }
      }
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end