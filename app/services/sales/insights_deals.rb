# Dali D5a — tratos para actuar (listas, estancadas, los que cubren la meta), para
# Sales::Insights. Usa sus permisos (open_opportunities, user_ids) y su `today`.
module Sales::InsightsDeals
  private

  def stale_block(ids)
    stale = V2::Reports::Cases::PipelineStaleBuilder.new(account: @account, params: pipeline_params(ids)).build
    { threshold_days: stale[:threshold_days], count: stale[:items].size,
      items: stale[:items].first(self.class::LIMIT).map { |i| i.slice(:folio, :title, :assignee_name, :stage, :days, :amount, :currency) } }
  end

  def gap_deals(range, ids, currency)
    rest = [Time.current, range.begin].max.to_date..range.end.to_date
    deal_rows(open_opportunities(ids).where(currency: currency, expected_close_at: rest)
      .order(Arel.sql('amount * COALESCE(probability, 50) DESC NULLS LAST')))
  end

  def deal_filter(scope, filter, ids)
    case filter
    when 'closing_this_week' then scope.where(expected_close_at: today.all_week).order(:expected_close_at)
    when 'overdue' then scope.where(expected_close_at: ...today).order(:expected_close_at)
    when 'committed_overdue' then scope.where.not(committed_at: nil).where(expected_close_at: ...today)
    when 'stale' then scope.where(id: stale_ids(ids))
    when 'top_open' then scope.order(Arel.sql('amount DESC NULLS LAST'))
    when 'won_recent' then scope.order(outcome_at: :desc)
    else scope.where(expected_close_at: today.all_month).order(Arel.sql('amount DESC NULLS LAST'))
    end
  end

  def stale_ids(ids)
    items = V2::Reports::Cases::PipelineStaleBuilder.new(account: @account, params: pipeline_params(ids)).build[:items]
    items.pluck(:id)
  end

  def pipeline_params(ids)
    ActionController::Parameters.new(ids ? { assignee_id: ids.first } : {}).permit!
  end

  def deal_rows(scope)
    scope.includes(:assignee, :contact, :organization, :case_type_column).limit(self.class::LIMIT).map { |t| deal_row(t) }
  end

  def deal_row(ticket)
    { id: ticket.id, folio: ticket.folio, title: ticket.title, client: (ticket.organization || ticket.contact)&.name,
      seller: ticket.assignee&.name, stage: ticket.case_type_column&.label, amount: ticket.amount&.to_f,
      currency: ticket.currency, probability: ticket.probability, expected_close_at: ticket.expected_close_at&.iso8601,
      committed: ticket.committed_at.present? }
  end
end
