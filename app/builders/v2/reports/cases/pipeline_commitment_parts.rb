# frozen_string_literal: true

# @tickets_cases — Plan-Metricas-Comercial: oportunidades «comprometidas por el
# cliente» («esta semana te pago»). Una sola fecha: si está comprometida,
# `expected_close_at` es la que prometió el cliente (pronóstico confirmado); si
# no, es el estimado del vendedor (probable). Requiere `open_scope`,
# `decided_scope`, `money` y `rate` del builder.
module V2::Reports::Cases::PipelineCommitmentParts
  COMMITTED_AMOUNT = 'COALESCE(SUM(case_tickets.amount) FILTER (WHERE case_tickets.committed_at IS NOT NULL), 0)'

  private

  def committed_open
    open_scope.where.not(committed_at: nil)
  end

  # Lo comprometido por ventana de la fecha prometida, y lo probable (sin
  # compromiso, ponderado) que cierra este mes. Ninguna cuenta en las dos.
  def commitments
    today = Time.zone.today
    {
      this_week: money_rows(committed_open.where(expected_close_at: today.all_week)),
      this_month: money_rows(committed_open.where(expected_close_at: today.all_month)),
      overdue: money_rows(committed_open.where(expected_close_at: ...today)),
      probable_this_month: money_rows(open_scope.where(committed_at: nil, expected_close_at: today.all_month))
    }
  end

  def money_rows(scope)
    scope.group('case_tickets.currency')
         .pluck('case_tickets.currency', Arel.sql('COUNT(*)'), Arel.sql(self.class::AMOUNT), Arel.sql(self.class::WEIGHTED))
         .map { |cur, n, amount, weighted| money(cur, amount: amount, weighted: weighted, count: n) }
  end

  # «Promesas cumplidas»: de las comprometidas que se decidieron en el período,
  # las ganadas a más tardar en la fecha prometida y SIN haberla movido.
  def promises
    scope = decided_scope.where.not(committed_at: nil)
    decided = scope.count
    moved = CaseEvent.where(account_id: account.id, event_type: :commitment_changed)
                     .where("case_events.payload->>'action' = 'moved'").select(:case_ticket_id)
    kept = scope.where(outcome: :won)
                .where('case_tickets.outcome_at::date <= case_tickets.expected_close_at')
                .where.not(id: moved).count
    { promises_decided: decided, promises_kept: kept, promises_rate: rate(kept, decided) }
  end
end
