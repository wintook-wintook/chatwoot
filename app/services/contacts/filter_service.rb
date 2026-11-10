class Contacts::FilterService < FilterService
  ATTRIBUTE_MODEL = 'contact_attribute'.freeze

  def initialize(account, user, params)
    @account = account
    # TODO: Change the order of arguments in FilterService maybe?
    # account, user, params makes more sense
    super(params, user)
  end

  def perform
    @contacts = query_builder(@filters['contacts'])

    {
      contacts: @contacts,
      count: @contacts.count
    }
  end

  def filter_values(query_hash)
    current_val = query_hash['values'][0]
    if query_hash['attribute_key'] == 'phone_number'
      "+#{current_val}"
    elsif query_hash['attribute_key'] == 'country_code'
      current_val.downcase
    else
      current_val.is_a?(String) ? current_val.downcase : current_val
    end
  end

  # TODO: @account.contacts.resolved_contacts ? to stay consistant with the behavior in ui
  def base_relation
    @account.contacts
  end

  def filter_config
    {
      entity: 'Contact',
      table_name: 'contacts'
    }
  end

  # Plan-Eventos E2 — está (o no) en un evento con ese estado. Cada valor es
  # «<event_id|any>:<estado|any>»; varios valores se suman con OR.
  def event_filter_query(query_hash)
    conditions = Array(query_hash['values']).filter_map { |value| event_condition(value) }
    return '' if conditions.empty?

    exists = 'EXISTS (SELECT 1 FROM event_attendees ea WHERE ea.contact_id = contacts.id ' \
             "AND ea.account_id = #{@account.id.to_i} AND (#{conditions.join(' OR ')}))"
    negate = query_hash[:filter_operator] == 'not_equal_to' ? 'NOT ' : ''
    "#{negate}#{exists} #{query_hash[:query_operator]}"
  end

  private

  # Solo números y estados conocidos llegan al SQL.
  def event_condition(value)
    event_id, status = value.to_s.split(':', 2)
    parts = []
    parts << "ea.event_id = #{event_id.to_i}" if event_id.to_s.match?(/\A\d+\z/)
    parts << "ea.status = #{EventAttendee.statuses[status]}" if EventAttendee.statuses.key?(status.to_s)
    return if parts.empty? && !(event_id == 'any' && status == 'any')

    parts.empty? ? 'TRUE' : "(#{parts.join(' AND ')})"
  end

  def equals_to_filter_string(filter_operator, current_index)
    return "= :value_#{current_index}" if filter_operator == 'equal_to'

    "!= :value_#{current_index}"
  end
end
