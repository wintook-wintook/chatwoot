# frozen_string_literal: true

# @tickets_cases — Plan-Metricas-Comercial M2 («Dinero en juego»): piezas de lo
# ABIERTO que usa V2::Reports::Cases::PipelineBuilder (se separan para no
# inflar el builder). Requiere `open_scope` y `money` del builder.
module V2::Reports::Cases::PipelineOpenParts
  ATTENTION_LIMIT = 10

  private

  # M2 — lo abierto con cierre estimado en el mes en curso, por moneda.
  def closing_this_month
    open_scope.where(expected_close_at: Time.zone.today.all_month).group('case_tickets.currency')
              .pluck('case_tickets.currency', Arel.sql('COUNT(*)'), Arel.sql(self.class::AMOUNT), Arel.sql(self.class::WEIGHTED))
              .map { |cur, n, amount, weighted| money(cur, amount: amount, weighted: weighted, count: n) }
  end

  # M2 — «Requieren atención»: abiertas con la fecha ya vencida, las de mayor
  # monto primero (las estancadas se suman en el front tras «Calcular»). Primero
  # las PROMESAS vencidas (el cliente se comprometió y no pagó: lo más cerca del
  # dinero), luego los cierres estimados vencidos. `reason` dice cuál es.
  def attention
    overdue = open_scope.where(expected_close_at: ...Time.zone.today).includes(:assignee, :case_type_column)
                        .order(Arel.sql('case_tickets.amount DESC NULLS LAST'), :expected_close_at)
    promised = overdue.where.not(committed_at: nil).limit(ATTENTION_LIMIT).to_a
    rest = overdue.where(committed_at: nil).limit(ATTENTION_LIMIT - promised.size).to_a
    promised.map { |t| opportunity_row(t).merge(reason: 'promise_overdue') } +
      rest.map { |t| opportunity_row(t).merge(reason: 'close_overdue') }
  end

  def opportunity_row(ticket)
    { id: ticket.id, folio: ticket.folio, title: ticket.title, assignee_name: ticket.assignee&.name,
      stage: ticket.case_type_column&.label, amount: ticket.amount&.to_f, currency: ticket.currency,
      expected_close_at: ticket.expected_close_at, committed: ticket.committed? }
  end

  # ── Embudo por etapa ─────────────────────────────────────────────────────────

  # Abiertas por columna del embudo. Se agrupa por la ETIQUETA de la columna: sin
  # filtro de tipo, «Propuesta» de dos tipos distintos es la misma etapa (los tipos
  # Comercial nacen con el mismo embudo). Sin columna → label nil («Sin etapa» en el front).
  def stages
    rows = open_scope.left_joins(:case_type_column)
                     .group('case_type_columns.label', 'case_tickets.currency')
                     .pluck('case_type_columns.label', Arel.sql('MIN(case_type_columns.position)'),
                            'case_tickets.currency', Arel.sql('COUNT(*)'), Arel.sql(self.class::AMOUNT), Arel.sql(self.class::WEIGHTED),
                            Arel.sql(self.class::WAITING))
    stage_rows = rows.group_by(&:first).map { |label, group| stage_row(label, group) }
    stage_rows.sort_by { |s| [s[:position], s[:label].to_s] }
  end

  # group: [[label, position, currency, count, amount, weighted, waiting], ...] de una etapa.
  def stage_row(label, group)
    {
      label: label,
      waiting: group.all? { |r| r[6] == true },
      position: group.filter_map { |r| r[1] }.min || 999,
      count: group.sum { |r| r[3] },
      values: group.map { |row| money(row[2], amount: row[4], weighted: row[5]) }
    }
  end

  # ── Pronóstico ───────────────────────────────────────────────────────────────

  # Abiertas con cierre estimado, por mes y moneda: monto, ponderado y la parte
  # COMPROMETIDA por el cliente (`committed`, monto completo). Los meses ya
  # pasados quedan (son oportunidades con la fecha vencida, que hay que revisar).
  def forecast
    month = "TO_CHAR(DATE_TRUNC('month', case_tickets.expected_close_at), 'YYYY-MM')"
    open_scope.where.not(expected_close_at: nil)
              .group(Arel.sql(month), 'case_tickets.currency')
              .order(Arel.sql(month))
              .pluck(Arel.sql(month), 'case_tickets.currency', Arel.sql('COUNT(*)'), Arel.sql(self.class::AMOUNT),
                     Arel.sql(self.class::WEIGHTED), Arel.sql(self.class::COMMITTED_AMOUNT))
              .map { |row| forecast_row(row) }
  end

  # row: [month, currency, count, amount, weighted, committed]
  def forecast_row(row)
    month, currency, count, amount, weighted, committed = row
    money(currency, amount: amount, weighted: weighted, count: count).merge(month: month, committed: committed.to_f.round(2))
  end
end
