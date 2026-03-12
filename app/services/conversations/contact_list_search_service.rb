# frozen_string_literal: true

# ================================================================================
# proyecto@search_by_contacts
# ================================================================================
# Service to search conversations by a list of phone numbers and/or emails
#
# Búsqueda de teléfonos flexible:
# - Compara los últimos 10 dígitos ignorando espacios y caracteres especiales
# - Ejemplo: buscar "3001234567" encuentra "+573001234567", "+57-300-123-4567", etc.
#
# Usage:
#   result = Conversations::ContactListSearchService.new(
#     account: Current.account,
#     user: Current.user,
#     params: { phone_numbers: ['3001234567', '+573009876543'], emails: ['cliente@email.com'], status: 'all', page: 1 }
#   ).perform
#
class Conversations::ContactListSearchService
  MAX_ITEMS_PER_REQUEST = 100
  DEFAULT_PER_PAGE = 25

  attr_reader :account, :user, :params

  def initialize(account:, user:, params: {})
    @account = account
    @user = user
    @params = params
  end

  def perform
    return empty_result if no_search_criteria?
    return error_result('Too many items') if exceeds_max_items?

    contact_ids = find_contacts
    return empty_result if contact_ids.empty?

    @conversations = find_conversations(contact_ids)
    build_result
  end

  private

  def no_search_criteria?
    phone_numbers.blank? && emails.blank?
  end

  def exceeds_max_items?
    (phone_numbers.size + emails.size) > MAX_ITEMS_PER_REQUEST
  end

  def phone_numbers
    @phone_numbers ||= Array(params[:phone_numbers]).compact.map(&:strip).reject(&:blank?)
  end

  # Normaliza los teléfonos: extrae solo dígitos y toma los últimos 10
  # Ejemplo: "+57-300-123-4567" => "3001234567"
  def normalized_phone_numbers
    @normalized_phone_numbers ||= phone_numbers.map { |phone| phone.gsub(/\D/, '').last(10) }.reject(&:blank?)
  end

  def emails
    @emails ||= Array(params[:emails]).compact.map { |e| e.strip.downcase }.reject(&:blank?)
  end

  def status_filter
    params[:status] || 'all'
  end

  def current_page
    params[:page] || 1
  end

  def find_contacts
    contacts_query = account.contacts

    if normalized_phone_numbers.present? && emails.present?
      contacts_query = contacts_query.where(
        "#{phone_number_match_sql} OR LOWER(email) IN (?)",
        normalized_phone_numbers,
        emails
      )
    elsif normalized_phone_numbers.present?
      contacts_query = contacts_query.where(phone_number_match_sql, normalized_phone_numbers)
    elsif emails.present?
      contacts_query = contacts_query.where('LOWER(email) IN (?)', emails)
    end

    contacts_query.pluck(:id)
  end

  # SQL para comparar los últimos 10 dígitos del phone_number
  # Elimina todos los caracteres no numéricos y compara los últimos 10 dígitos
  def phone_number_match_sql
    "RIGHT(REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g'), 10) IN (?)"
  end

  def find_conversations(contact_ids)
    conversations_query = account.conversations
                                 .where(contact_id: contact_ids)
                                 .where(inbox_id: accessible_inbox_ids)

    conversations_query = apply_status_filter(conversations_query)
    conversations_query
  end

  def accessible_inbox_ids
    @accessible_inbox_ids ||= user.assigned_inboxes.pluck(:id)
  end

  def apply_status_filter(query)
    return query if status_filter == 'all'

    query.where(status: status_filter)
  end

  def build_result
    mine_count = @conversations.assigned_to(user).count
    unassigned_count = @conversations.unassigned.count
    all_count = @conversations.count
    assigned_count = all_count - unassigned_count

    {
      conversations: paginated_conversations,
      count: {
        mine_count: mine_count,
        assigned_count: assigned_count,
        unassigned_count: unassigned_count,
        all_count: all_count
      }
    }
  end

  def paginated_conversations
    @conversations
      .includes(
        :taggings,
        :inbox,
        { assignee: { avatar_attachment: [:blob] } },
        { contact: { avatar_attachment: [:blob] } },
        :team,
        :contact_inbox
      )
      .sort_on_last_activity_at('desc')
      .page(current_page)
      .per(DEFAULT_PER_PAGE)
  end

  def empty_result
    {
      conversations: [],
      count: {
        mine_count: 0,
        assigned_count: 0,
        unassigned_count: 0,
        all_count: 0
      }
    }
  end

  def error_result(message)
    {
      error: message,
      conversations: [],
      count: {
        mine_count: 0,
        assigned_count: 0,
        unassigned_count: 0,
        all_count: 0
      }
    }
  end
end
