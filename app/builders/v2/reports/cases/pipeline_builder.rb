# frozen_string_literal: true

# @tickets_cases — Plan-Clase-Comercial F5
#
# Métricas del embudo comercial, solo sobre casos de la clase Comercial. Dos
# relojes distintos, a propósito:
#   - Lo ABIERTO (valor en proceso, ponderado, etapas, pronóstico) es una foto de
#     hoy: no se acota por fecha — una oportunidad abierta hace meses sigue viva.
#   - Lo DECIDIDO (ganadas, perdidas, canceladas, tasa de cierre, ciclo, motivos)
#     se acota por `outcome_at` dentro del rango: «qué se cerró en el período».
# Los montos se agrupan SIEMPRE por moneda: nunca se suman pesos con dólares.
class V2::Reports::Cases::PipelineBuilder < V2::Reports::Cases::BaseBuilder
  SECONDS_PER_DAY = 86_400.0
  AMOUNT   = 'COALESCE(SUM(case_tickets.amount), 0)'
  WEIGHTED = 'COALESCE(SUM(case_tickets.amount * COALESCE(case_tickets.probability, 0) / 100.0), 0)'

  def build
    {
      summary: summary,
      stages: stages,
      loss_reasons: loss_reasons,
      by_assignee: by_assignee,
      by_type: by_type,
      forecast: forecast
    }
  end

  private

  def commercial_tickets
    filtered_tickets.commercial
  end

  def open_scope
    commercial_tickets.where(status: CaseTicket::PENDING_STATUSES)
  end

  def decided_scope
    scope = commercial_tickets.where.not(outcome: nil)
    range ? scope.where(case_tickets: { outcome_at: range }) : scope
  end

  # ── Resumen ──────────────────────────────────────────────────────────────────

  def summary
    open_summary.merge(decided_summary)
  end

  def open_summary
    open_rows = open_scope.group('case_tickets.currency')
                          .pluck('case_tickets.currency', Arel.sql('COUNT(*)'), Arel.sql(AMOUNT), Arel.sql(WEIGHTED))
    {
      open_count: open_rows.sum { |r| r[1] },
      postponed_count: open_scope.where.not(postponed_until: nil).count,
      open_value: open_rows.map { |cur, _n, amount, weighted| money(cur, amount: amount, weighted: weighted) }
    }
  end

  def decided_summary
    {
      won_count: decided_counts['won'],
      lost_count: decided_counts['lost'],
      cancelled_count: decided_counts['cancelled'],
      won_value: decided_values('won'),
      lost_value: decided_values('lost'),
      win_rate: rate(decided_counts['won'], decided_counts['won'] + decided_counts['lost']),
      avg_cycle_days: avg_cycle_days,
      recovered_count: recovered_count
    }
  end

  def decided_rows
    @decided_rows ||= decided_scope.group('case_tickets.outcome', 'case_tickets.currency')
                                   .pluck('case_tickets.outcome', 'case_tickets.currency',
                                          Arel.sql('COUNT(*)'), Arel.sql(AMOUNT))
                                   .map { |outcome, cur, n, amount| [outcome_key(outcome), cur, n, amount] }
  end

  def decided_counts
    @decided_counts ||= CaseTicket.outcomes.keys.index_with do |key|
      decided_rows.select { |r| r[0] == key }.sum { |r| r[2] }
    end
  end

  def decided_values(key)
    decided_rows.select { |r| r[0] == key }.map { |_k, cur, n, amount| money(cur, amount: amount, count: n) }
  end

  # Días promedio de alta → ganada, solo de lo ganado en el período.
  def avg_cycle_days
    seconds = decided_scope.where(outcome: :won)
                           .average(Arel.sql('EXTRACT(EPOCH FROM (case_tickets.outcome_at - case_tickets.created_at))'))
    seconds && (seconds.to_f / SECONDS_PER_DAY).round(1)
  end

  # Ganadas en el período que antes se habían dado por perdidas o canceladas
  # (al reabrir, el evento `reopened` guarda `previous_outcome`).
  def recovered_count
    won_ids = decided_scope.where(outcome: :won).pluck(:id)
    return 0 if won_ids.empty?

    CaseEvent.where(case_ticket_id: won_ids, event_type: :reopened)
             .where("payload->>'previous_outcome' IN ('lost', 'cancelled')")
             .distinct.count(:case_ticket_id)
  end

  # ── Embudo por etapa ─────────────────────────────────────────────────────────

  # Abiertas por columna del embudo. Se agrupa por la ETIQUETA de la columna: sin
  # filtro de tipo, «Propuesta» de dos tipos distintos es la misma etapa (los tipos
  # Comercial nacen con el mismo embudo). Sin columna → label nil («Sin etapa» en el front).
  def stages
    rows = open_scope.left_joins(:case_type_column)
                     .group('case_type_columns.label', 'case_tickets.currency')
                     .pluck('case_type_columns.label', Arel.sql('MIN(case_type_columns.position)'),
                            'case_tickets.currency', Arel.sql('COUNT(*)'), Arel.sql(AMOUNT), Arel.sql(WEIGHTED))
    stage_rows = rows.group_by(&:first).map { |label, group| stage_row(label, group) }
    stage_rows.sort_by { |s| [s[:position], s[:label].to_s] }
  end

  # group: [[label, position, currency, count, amount, weighted], ...] de una etapa.
  def stage_row(label, group)
    {
      label: label,
      position: group.filter_map { |r| r[1] }.min || 999,
      count: group.sum { |r| r[3] },
      values: group.map { |row| money(row[2], amount: row[4], weighted: row[5]) }
    }
  end

  # ── Motivos de pérdida / cancelación ─────────────────────────────────────────

  def loss_reasons
    decided_scope.where(outcome: %i[lost cancelled])
                 .left_joins(:outcome_reason)
                 .group('case_tickets.outcome', 'case_outcome_reasons.label')
                 .pluck('case_tickets.outcome', 'case_outcome_reasons.label', Arel.sql('COUNT(*)'))
                 .map { |outcome, label, n| { outcome: outcome_key(outcome), label: label, count: n } }
                 .sort_by { |r| -r[:count] }
  end

  # ── Por vendedor y por tipo ──────────────────────────────────────────────────

  def by_assignee
    rows = breakdown('case_tickets.assignee_id')
    names = account.users.where(id: rows.keys.compact).pluck(:id, :name).to_h
    rows.map { |id, row| row.merge(assignee_id: id, assignee_name: names[id]) }
        .sort_by { |r| [-r[:won_count], -r[:open_count]] }
  end

  def by_type
    rows = breakdown('case_tickets.case_type_id')
    names = account.case_types.where(id: rows.keys.compact).pluck(:id, :name).to_h
    rows.map { |id, row| row.merge(case_type_id: id, case_type_name: names[id]) }
        .sort_by { |r| [-r[:won_count], -r[:open_count]] }
  end

  # Abierto (conteo, valor, ponderado por moneda) + decidido (conteos, ganado por
  # moneda) agrupados por una columna. → { key => row }
  def breakdown(column)
    rows = Hash.new { |h, k| h[k] = empty_row }
    add_open_rows(rows, column)
    add_decided_rows(rows, column)
    rows.each_value { |row| row[:win_rate] = rate(row[:won_count], row[:won_count] + row[:lost_count]) }
    rows
  end

  def add_open_rows(rows, column)
    open_scope.group(column, 'case_tickets.currency')
              .pluck(column, 'case_tickets.currency', Arel.sql('COUNT(*)'), Arel.sql(AMOUNT), Arel.sql(WEIGHTED))
              .each do |key, cur, n, amount, weighted|
      rows[key][:open_count] += n
      rows[key][:open_value] << money(cur, amount: amount, weighted: weighted)
    end
  end

  def add_decided_rows(rows, column)
    decided_scope.group(column, 'case_tickets.outcome', 'case_tickets.currency')
                 .pluck(column, 'case_tickets.outcome', 'case_tickets.currency', Arel.sql('COUNT(*)'), Arel.sql(AMOUNT))
                 .each do |key, outcome, cur, n, amount|
      row = rows[key]
      row[:"#{outcome_key(outcome)}_count"] += n
      row[:won_value] << money(cur, amount: amount) if outcome_key(outcome) == 'won'
    end
  end

  def empty_row
    { open_count: 0, open_value: [], won_count: 0, lost_count: 0, cancelled_count: 0, won_value: [] }
  end

  # ── Pronóstico ───────────────────────────────────────────────────────────────

  # Abiertas con cierre estimado, por mes y moneda: monto y ponderado. Los meses
  # ya pasados quedan (son oportunidades con la fecha vencida, que hay que revisar).
  def forecast
    month = "TO_CHAR(DATE_TRUNC('month', case_tickets.expected_close_at), 'YYYY-MM')"
    open_scope.where.not(expected_close_at: nil)
              .group(Arel.sql(month), 'case_tickets.currency')
              .order(Arel.sql(month))
              .pluck(Arel.sql(month), 'case_tickets.currency', Arel.sql('COUNT(*)'), Arel.sql(AMOUNT), Arel.sql(WEIGHTED))
              .map { |m, cur, n, amount, weighted| money(cur, amount: amount, weighted: weighted, count: n).merge(month: m) }
  end

  # ── utilidades ───────────────────────────────────────────────────────────────

  def money(currency, amount:, weighted: nil, count: nil)
    { currency: currency, amount: amount.to_f.round(2), weighted: weighted&.to_f&.round(2), count: count }.compact
  end

  def rate(part, total)
    total.zero? ? nil : (part.to_f / total * 100).round
  end

  def outcome_key(raw)
    enum_key(CaseTicket.outcomes, raw)
  end
end
