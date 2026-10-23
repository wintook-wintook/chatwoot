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
      Current.account.conversations.includes(:account, :assignee, :contact, :inbox, :kanban_process)
    end
  
    def apply_kanban_filters(conversations)
      conversations = conversations.where(kanban_type_process_id: params[:kanban_type_process_id]) if params[:kanban_type_process_id].present?
      conversations = conversations.where(kanban_process_id: params[:kanban_process_id]) if params[:kanban_process_id].present?
      conversations = conversations.where(status: params[:status]) if params[:status].present?
      conversations = conversations.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
      conversations
    end
  
    # Embudo de contactos — la tarjeta muestra quién la movió y por qué, y el último
    # caso que nació de la conversación (el chip «→ F-102»).
    def with_funnel_info(conversations)
      list = conversations.to_a
      cases = cases_by_conversation(list.map(&:id))
      people = User.where(id: list.filter_map(&:kanban_moved_by_id).uniq).pluck(:id, :name).to_h
      cold = cold_ids(list)
      list.map do |conversation|
        conversation.push_event_data.merge(
          kanban_move: kanban_move_json(conversation, people),
          case_ticket: cases[conversation.id],
          kanban_cold: cold.include?(conversation.id)
        )
      end
    end

    # E2 — «Frío»: tarjeta abierta cuyo cliente no escribe en los días del tablero.
    def cold_ids(list)
      boards = KanbanTypeProcess.where(id: list.map(&:kanban_type_process_id).uniq).where.not(cold_after_days: nil)
                                .index_by(&:id)
      candidates = list.select { |c| boards[c.kanban_type_process_id] && c.kanban_process&.stage_open? }
      return Set.new if candidates.empty?

      last = Message.unscoped.where(conversation_id: candidates.map(&:id), message_type: :incoming)
                    .group(:conversation_id).maximum(:created_at)
      candidates.select do |c|
        (last[c.id] || c.created_at) < boards[c.kanban_type_process_id].cold_after_days.days.ago
      end.to_set(&:id)
    end

    def kanban_move_json(conversation, people)
      return nil if conversation.kanban_moved_at.nil?

      { source: conversation.kanban_move_source, reason: conversation.kanban_move_reason,
        at: conversation.kanban_moved_at.to_i, by: people[conversation.kanban_moved_by_id] }
    end

    def cases_by_conversation(ids)
      return {} if ids.empty?

      CaseTicket.where(account_id: Current.account.id, conversation_id: ids)
                .order(created_at: :desc).pluck(:conversation_id, :id, :folio)
                .each_with_object({}) { |(conversation_id, id, folio), map| map[conversation_id] ||= { id: id, folio: folio } }
    end

    def render_response(conversations)
      render json: {
        data: with_funnel_info(conversations),
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