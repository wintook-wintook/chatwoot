# El monto de la oportunidad es siempre SIN IVA. Hasta hoy, al ligarse a una sola
# cotización o al ganarse con una, copiaba su total CON IVA. Se corrige lo existente:
#   · con cotización ganada → subtotal − descuento de esa cotización;
#   · abierta con UNA sola cotización (el espejo) → subtotal − descuento de esa.
class NetAmountOnQuotedOpportunities < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL.squish
      UPDATE case_tickets SET amount = q.net, currency = q.currency
      FROM (SELECT DISTINCT ON (opportunity_id) opportunity_id, subtotal - discount_total AS net, currency
            FROM quotes WHERE status = 2 AND opportunity_id IS NOT NULL
            ORDER BY opportunity_id, decided_at DESC NULLS LAST, id DESC) q
      WHERE case_tickets.id = q.opportunity_id
    SQL
    execute <<~SQL.squish
      UPDATE case_tickets SET amount = q.net, currency = q.currency
      FROM (SELECT opportunity_id, MIN(subtotal - discount_total) AS net, MIN(currency) AS currency
            FROM quotes WHERE opportunity_id IS NOT NULL
            GROUP BY opportunity_id HAVING COUNT(*) = 1) q
      WHERE case_tickets.id = q.opportunity_id AND case_tickets.outcome IS NULL
        AND case_tickets.status NOT IN (7, 8)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
