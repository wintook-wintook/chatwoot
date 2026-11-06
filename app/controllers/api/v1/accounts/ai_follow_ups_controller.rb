# frozen_string_literal: true

# Seguimiento IA — delegar un seguimiento al agente nuevo y manejarlo.
#   GET  …/ai_follow_ups?case_id= | ?conversation_id=(display_id) | ?contact_id=   → los últimos (el vivo primero)
#   POST …/ai_follow_ups { conversation_id (display_id), case_id, objective, instructions, starts_at,
#                          max_attempts, interval_value, interval_unit, on_finish, tz }
#   POST …/ai_follow_ups/:id/pause | resume | cancel
#   GET  …/ai_follow_ups/templates?conversation_id=   → plantillas de WhatsApp que el agente puede usar
#   GET  …/ai_follow_ups/context?conversation_id=     → si hay respuestas predefinidas y la nota IA del contacto
# Todo con los permisos de quien lo pide (Access::Grant): solo conversaciones y casos que ve.
class Api::V1::Accounts::AiFollowUpsController < Api::V1::Accounts::BaseController
  LIMIT = 5

  before_action :set_follow_up, only: %i[pause resume cancel]

  def index
    rows = index_scope.order(Arel.sql("CASE WHEN status IN ('active','paused') THEN 0 ELSE 1 END"), created_at: :desc).limit(LIMIT)
    render json: { payload: rows.map { |f| follow_up_json(f) } }
  end

  def create
    ticket = params[:case_id].present? ? visible_case(params[:case_id]) : nil
    conversation = params[:conversation_id].present? ? visible_conversation(params[:conversation_id]) : ticket&.conversation
    follow_up = AiFollowUps::Creator.new(account: Current.account, user: current_user, conversation: conversation,
                                         case_ticket: ticket, params: create_params).call
    render json: { payload: follow_up_json(follow_up) }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def templates
    finder = AiFollowUps::Templates.new(visible_conversation(params[:conversation_id]))
    render json: { whatsapp: finder.whatsapp?, payload: finder.available.map { |t| t.except(:namespace) } }
  end

  def context
    conversation = visible_conversation(params[:conversation_id])
    note = AiFollowUps::Prompt.ai_note(conversation.contact)
    render json: { canned: AiFollowUps::KnowledgeSearch.new(account: Current.account).canned_available?,
                   ai_note: note && { content: note.content, updated_at: note.updated_at },
                   contact_id: conversation.contact_id }
  end

  def pause = change(:pause!)
  def resume = change(:resume!)
  def cancel = change(:cancel!)

  private

  def index_scope
    scope = AiFollowUp.where(account_id: Current.account.id)
    if params[:case_id].present?
      scope.where(case_ticket_id: visible_case(params[:case_id]).id)
    elsif params[:contact_id].present?
      scope.where(conversation_id: visible_conversations.where(contact_id: params[:contact_id]).select(:id))
    else
      scope.where(conversation_id: visible_conversation(params[:conversation_id]).id)
    end
  end

  def change(action)
    if @follow_up.public_send(action, by: current_user)
      render json: { payload: follow_up_json(@follow_up) }
    else
      render json: { error: "Está #{@follow_up.status}: no se puede." }, status: :unprocessable_entity
    end
  end

  def set_follow_up
    @follow_up = AiFollowUp.where(account_id: Current.account.id).find(params[:id])
    visible_conversation(@follow_up.conversation.display_id)
  end

  def visible_case(id)
    access_grant.case_tickets(Current.account.case_tickets).find(id)
  end

  def visible_conversation(display_id)
    visible_conversations.find_by!(display_id: display_id)
  end

  def visible_conversations
    access_grant.conversations(Current.account.conversations)
  end

  def create_params
    params.permit(:objective, :instructions, :starts_at, :max_attempts, :interval_value, :interval_unit, :on_finish,
                  :template_name, :template_language)
          .to_h.merge('time_zone' => (params[:tz] if ActiveSupport::TimeZone[params[:tz].to_s]))
  end

  ATTRS = %i[id status objective instructions attempts max_attempts interval_value interval_unit on_finish next_run_at
             outcome last_error template_name created_at finished_at].freeze

  def follow_up_json(follow_up)
    follow_up.slice(*ATTRS).merge(
      name: AiFollowUp::DISPLAY_NAME, last_template: last_template(follow_up), created_by: follow_up.created_by&.name,
      conversation_id: follow_up.conversation.display_id, case_id: follow_up.case_ticket_id,
      log: Array(follow_up.log).last(15).reverse
    )
  end

  def last_template(follow_up)
    Array(follow_up.log).reverse.find { |e| e['kind'] == 'template' }&.dig('text').to_s.split(/ — |: /).first
  end
end
