# Campañas con IA — filtros de contactos para armar la audiencia sin segmento (también sirven en segmentos):
#   inactive_customer «<días>:<categoría|any>»  compró alguna vez (cotización ganada o contrato) y su última compra
#                                               fue hace más de N días, sin contrato activo (Reactivar)
#   contract_due      «<días>:<tipo|any>»       tiene un contrato activo que se cobra o termina en los próximos N días
#                                               (Recordar)
#   served_recently   «<días>»                  lo atendimos en los últimos N días: caso cerrado/resuelto o cotización
#                                               ganada (Encuesta)
# Solo números llegan al SQL. Se incluye en Contacts::FilterService (FilterHelper#handle_standard_attributes).
module Contacts::CampaignAudienceFilters
  CATEGORY_TREE = 'SELECT id FROM catalog_categories WHERE account_id = %<account>d AND (id = %<id>d OR parent_id = %<id>d)'.freeze

  def campaign_audience_query(query_hash)
    value = Array(query_hash['values']).first.to_s
    sql = case query_hash['attribute_key']
          when 'inactive_customer' then inactive_customer_sql(*value.split(':', 2))
          when 'contract_due' then contract_due_sql(*value.split(':', 2))
          when 'served_recently' then served_recently_sql(value)
          end
    return '' if sql.blank?

    negate = query_hash[:filter_operator] == 'not_equal_to' ? 'NOT ' : ''
    "#{negate}(#{sql}) #{query_hash[:query_operator]}"
  end

  private

  def audience_days(raw) = raw.to_s.match?(/\A\d+\z/) ? raw.to_i.clamp(1, 3650) : nil
  def audience_id(raw) = raw.to_s.match?(/\A\d+\z/) ? raw.to_i : nil

  def inactive_customer_sql(days, category)
    days = audience_days(days)
    return unless days

    account = @account.id.to_i
    items = category_items_sql(audience_id(category))
    quotes = "SELECT q.contact_id, COALESCE(q.decided_at, q.updated_at) AS at FROM quotes q WHERE q.account_id = #{account} AND q.status = 2"
    quotes += " AND EXISTS (SELECT 1 FROM quote_items qi WHERE qi.quote_id = q.id AND qi.catalog_item_id IN (#{items}))" if items
    contracts = "SELECT c.contact_id, c.starts_on::timestamp AS at FROM contracts c WHERE c.account_id = #{account}"
    contracts += " AND c.catalog_item_id IN (#{items})" if items
    "contacts.id IN (SELECT p.contact_id FROM (#{quotes} UNION ALL #{contracts}) p GROUP BY p.contact_id " \
      "HAVING MAX(p.at) < NOW() - INTERVAL '#{days} days') AND NOT EXISTS (SELECT 1 FROM contracts ac " \
      "WHERE ac.contact_id = contacts.id AND ac.account_id = #{account} AND ac.status = 0)"
  end

  def category_items_sql(category_id)
    return unless category_id

    tree = format(CATEGORY_TREE, account: @account.id.to_i, id: category_id)
    "SELECT ci.id FROM catalog_items ci WHERE ci.account_id = #{@account.id.to_i} AND ci.catalog_category_id IN (#{tree})"
  end

  def contract_due_sql(days, type)
    days = audience_days(days)
    return unless days

    type_id = audience_id(type)
    "EXISTS (SELECT 1 FROM contracts c WHERE c.contact_id = contacts.id AND c.account_id = #{@account.id.to_i} AND c.status = 0 " \
      "#{"AND c.contract_type_id = #{type_id} " if type_id}" \
      'AND LEAST(COALESCE(c.next_charge_on, c.ends_on), COALESCE(c.ends_on, c.next_charge_on)) ' \
      "BETWEEN CURRENT_DATE AND CURRENT_DATE + #{days})"
  end

  # Caso resuelto o cerrado (6, 7) o cotización ganada (2) en los últimos N días.
  def served_recently_sql(days)
    days = audience_days(days)
    return unless days

    account = @account.id.to_i
    since = "NOW() - INTERVAL '#{days} days'"
    "EXISTS (SELECT 1 FROM case_tickets t WHERE t.contact_id = contacts.id AND t.account_id = #{account} AND t.status IN (6, 7) " \
      "AND COALESCE(t.closed_at, t.resolved_at, t.updated_at) >= #{since}) OR EXISTS (SELECT 1 FROM quotes q " \
      "WHERE q.contact_id = contacts.id AND q.account_id = #{account} AND q.status = 2 AND q.decided_at >= #{since})"
  end
end
