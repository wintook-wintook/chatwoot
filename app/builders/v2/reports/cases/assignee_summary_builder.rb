# proyecto@metricas_casos
#
# Ranking de vendedores: no es lógica nueva, es la misma clasificación de
# DistributionBuilder#outcome (ver `outcome_bucket` en BaseBuilder) reagrupada por
# `assignee_id` en vez de por columna/tipo, más el tiempo promedio de cierre.
class V2::Reports::Cases::AssigneeSummaryBuilder < V2::Reports::Cases::BaseBuilder
  SECONDS_PER_DAY = 86_400.0

  def build
    avg_days = avg_close_days_by_assignee
    rows = outcome_counts_by_assignee.map { |assignee_id, buckets| build_row(assignee_id, buckets, avg_days) }
    rows.sort_by { |row| [-row[:won], -row[:open]] }
  end

  private

  def build_row(assignee_id, buckets, avg_days)
    decided = buckets[:won] + buckets[:lost]
    {
      assignee_id: assignee_id,
      assignee_name: assignee_names[assignee_id],
      open: buckets[:open],
      won: buckets[:won],
      lost: buckets[:lost],
      other_closed: buckets[:other_closed],
      conversion_rate: decided.zero? ? nil : (buckets[:won].to_f / decided * 100).round,
      avg_close_days: avg_days[assignee_id]&.round(1)
    }
  end

  def outcome_counts_by_assignee
    @outcome_counts_by_assignee ||= begin
      raw = scoped_tickets.group(:assignee_id, :status, :closure_type).count
      raw.each_with_object(Hash.new { |h, k| h[k] = { open: 0, won: 0, lost: 0, other_closed: 0 } }) do |entry, per_assignee|
        (assignee_id, status_raw, closure_raw), count = entry
        status = enum_key(CaseTicket.statuses, status_raw)
        closure = closure_raw.nil? ? nil : enum_key(CaseTicket.closure_types, closure_raw)
        per_assignee[assignee_id][outcome_bucket(status, closure)] += count
      end
    end
  end

  # `closed_at` solo se llena cuando `status: closed` (ver CaseTicket#transition!) —
  # un ticket "perdido directo" (`status: cancelled`) no tiene con qué medir esto.
  def avg_close_days_by_assignee
    seconds_by_assignee = scoped_tickets.where.not(closed_at: nil)
                                        .group(:assignee_id)
                                        .average(Arel.sql('EXTRACT(EPOCH FROM (closed_at - created_at))'))
    seconds_by_assignee.transform_values { |seconds| seconds.to_f / SECONDS_PER_DAY }
  end

  def assignee_names
    @assignee_names ||= account.users.where(id: outcome_counts_by_assignee.keys.compact)
                               .index_by(&:id).transform_values(&:name)
  end
end
