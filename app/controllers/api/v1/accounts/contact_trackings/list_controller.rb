# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — Dashboard de Seguimientos (Fase 4: Listado)
# ================================================================================
# GET /api/v1/accounts/:account_id/contact_trackings/list
#   Listado paginado y filtrable de seguimientos a nivel cuenta.
#   Filtros: status, inbox_id, template_id, last_intent, outcome,
#            date_from, date_to, q (objetivo / nombre de contacto), overdue.
#   Paginación: page (1), per_page (25, máx 100). Orden: scheduled_for desc.
#   Cada fila trae conversation_display_id para navegar a la conversación.
# ================================================================================
class Api::V1::Accounts::ContactTrackings::ListController < Api::V1::Accounts::BaseController
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE     = 100

  def index
    scope = filtered_scope
    total = scope.count
    records = scope.includes(:contact, :conversation, :inbox, :tracking_template)
                   .order(scheduled_for: :desc)
                   .offset((page - 1) * per_page)
                   .limit(per_page)

    # Estado de entrega (WhatsApp) por conversación, en batch ([[Entrega-vs-ejecucion]]).
    @last_messages = last_messages_by_conversation(records)

    render json: {
      trackings: records.map { |t| row(t) },
      meta: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }
  end

  private

  # { conversation_id => { status:, error: } } del último mensaje saliente de cada
  # conversación de la página, en 2 queries (sin N+1 por fila).
  def last_messages_by_conversation(records)
    conversation_ids = records.filter_map(&:conversation_id).uniq
    return {} if conversation_ids.empty?

    # reorder(nil): Message tiene default_scope con ORDER BY que rompe el GROUP BY.
    last_ids = Message.where(conversation_id: conversation_ids, message_type: %i[outgoing template])
                      .reorder(nil).group(:conversation_id).maximum(:id)
    return {} if last_ids.empty?

    Message.where(id: last_ids.values).each_with_object({}) do |message, acc|
      acc[message.conversation_id] = {
        status: message.status,
        error: message.content_attributes&.dig('external_error')
      }
    end
  end

  def filtered_scope
    rel = ContactTracking.where(account_id: Current.account.id)
    rel = rel.where(tracking_campaign_id: params[:campaign_id]) if params[:campaign_id].present? # @campanas_vendedor
    rel = rel.where(status: params[:status]) if params[:status].present?
    rel = rel.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    rel = rel.where(tracking_template_id: params[:template_id]) if params[:template_id].present?
    rel = rel.where(last_intent: params[:last_intent]) if params[:last_intent].present?
    rel = rel.where(outcome: params[:outcome]) if params[:outcome].present?
    rel = rel.where('contact_trackings.created_at >= ?', params[:date_from]) if params[:date_from].present?
    rel = rel.where('contact_trackings.created_at <= ?', params[:date_to]) if params[:date_to].present?
    rel = rel.where(status: %w[pending scheduled]).where('scheduled_for < ?', Time.current) if ActiveModel::Type::Boolean.new.cast(params[:overdue])
    if params[:q].present?
      q = "%#{params[:q].strip}%"
      rel = rel.left_joins(:contact).where('contact_trackings.objective ILIKE :q OR contacts.name ILIKE :q', q: q)
    end
    rel
  end

  def row(tracking)
    {
      id: tracking.id,
      status: tracking.status,
      objective: tracking.objective,
      scheduled_for: tracking.scheduled_for,
      appointment_at: tracking.appointment_at,
      last_intent: tracking.last_intent,
      outcome: tracking.outcome,
      last_error: tracking.last_error,
      attempt_count: tracking.attempt_count,
      max_attempts: tracking.max_attempts,
      inbox_id: tracking.inbox_id,
      inbox_name: tracking.inbox&.name,
      contact_id: tracking.contact_id,
      contact_name: tracking.contact&.name,
      tracking_template_id: tracking.tracking_template_id,
      template_name: tracking.tracking_template&.name,
      conversation_id: tracking.conversation_id,
      conversation_display_id: tracking.conversation&.display_id
    }.merge(delivery_fields(tracking))
  end

  # Estado de entrega (WhatsApp) del último mensaje saliente ([[Entrega-vs-ejecucion]]).
  def delivery_fields(tracking)
    last_message = @last_messages[tracking.conversation_id] || {}
    {
      last_message_status: last_message[:status],
      last_message_error: last_message[:error]
    }
  end

  def page
    [params[:page].to_i, 1].max
  end

  def per_page
    pp = params[:per_page].to_i
    pp = DEFAULT_PER_PAGE if pp <= 0
    [pp, MAX_PER_PAGE].min
  end
end
