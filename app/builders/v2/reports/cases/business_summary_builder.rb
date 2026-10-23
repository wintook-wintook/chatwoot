# frozen_string_literal: true

# @tickets_cases — «Resumen del negocio» (para el dueño): todo el negocio en una
# pantalla, que se lee en 30 segundos. Junta lo que ya calculan los reportes de
# cada clase (no recalcula a su manera) y responde una pregunta por bloque:
#   ventas    ¿cuánto vendimos? (▲▼ vs el rango de comparación) · ¿cuánto entra
#             pronto? (comprometido) · ¿cuánto hay en juego?
#   soporte   ¿estamos atendiendo bien? (SLA vencido, primera respuesta, satisfacción)
#   órdenes   ¿cumplimos en campo? (visitas vencidas, por agendar, terminadas)
#   proyectos ¿van a tiempo? (atrasados, en riesgo, sobre presupuesto)
#   conversaciones ¿cómo atendemos por chat? (BusinessSummaryConversations)
#   personas  ¿quién está jalando? (top vendedores) y quién tiene más vencido
#   attention «lo que necesita tu atención»: máx. 5, lo más grave primero
# Período: `since`/`until` (+ `prev_since`/`prev_until`, como Comercial). Lo
# abierto es foto de hoy. Una clase sin tipos en la cuenta no aparece.
class V2::Reports::Cases::BusinessSummaryBuilder < V2::Reports::Cases::BaseBuilder
  include V2::Reports::Cases::BusinessSummaryConversations

  ATTENTION_LIMIT = 5
  TOP = 3
  # [clave, clase] de lo más grave a lo menos.
  # `conversations` no es una clase de caso: aparece si la cuenta tiene bandejas.
  ATTENTION_ORDER = [%w[promises_overdue commercial], %w[unattended_conversations conversations],
                     %w[sla_overdue support], %w[visits_overdue work_order], %w[projects_late project],
                     %w[close_overdue commercial]].freeze

  def build
    classes = classes_in_use
    sections = classes + (account.inboxes.exists? ? ['conversations'] : [])
    {
      classes: classes,
      sales: classes.include?('commercial') ? sales : nil,
      support: classes.include?('support') ? support : nil,
      work_orders: classes.include?('work_order') ? work_orders : nil,
      projects: classes.include?('project') ? projects : nil,
      conversations: sections.include?('conversations') ? conversations_block : nil,
      people: people,
      attention: attention(sections)
    }.compact
  end

  private

  # Las clases que la cuenta usa (con al menos un tipo). Soporte también cuenta
  # si hay casos sin tipo.
  def classes_in_use
    used = account.case_types.distinct.pluck(:case_class).map { |c| c.presence || 'support' }
    used << 'support' if account.case_tickets.exists?(case_type_id: nil)
    %w[commercial support work_order project] & used.uniq
  end

  # ── Ventas ────────────────────────────────────────────────────────────────────

  def pipeline
    @pipeline ||= V2::Reports::Cases::PipelineBuilder.new(account: account, params: params).build
  end

  def sales
    s = pipeline[:summary]
    commitments = s[:commitments]
    {
      won_value: s[:won_value], won_count: s[:won_count], win_rate: s[:win_rate],
      previous: pipeline[:previous]&.slice(:won_value, :won_count, :win_rate),
      open_value: s[:open_value], open_count: s[:open_count],
      committed_week: commitments[:this_week], committed_month: commitments[:this_month],
      committed_overdue: commitments[:overdue],
      top_sellers: top_sellers
    }
  end

  def top_sellers
    pipeline[:by_assignee].select { |r| r[:assignee_id] && r[:won_count].positive? }.first(TOP)
                          .map { |r| r.slice(:assignee_id, :assignee_name, :won_count, :won_value) }
  end

  # ── Soporte ───────────────────────────────────────────────────────────────────

  def support_tickets
    filtered_tickets.with_capability(:sla)
  end

  def support
    @support ||= support_data
  end

  def support_data
    open = support_tickets.where(status: CaseTicket::PENDING_STATUSES)
    created = range ? support_tickets.where(created_at: range) : support_tickets
    {
      open_count: open.count, sla_overdue: open.overdue.count, sla_at_risk: open.at_risk.count,
      created_count: created.count,
      avg_first_response_minutes: avg_first_response(created),
      previous_avg_first_response_minutes: previous_range && avg_first_response(support_tickets.where(created_at: previous_range)),
      csat: csat(created)
    }
  end

  def avg_first_response(tickets)
    tickets.where.not(first_response_at: nil)
           .average(Arel.sql('EXTRACT(EPOCH FROM (first_response_at - created_at)) / 60'))&.to_f&.round(1)
  end

  def csat(tickets)
    convo_ids = tickets.where.not(conversation_id: nil).select(:conversation_id)
    responses = account.csat_survey_responses.where(conversation_id: convo_ids)
    count = responses.count
    { avg: count.zero? ? nil : responses.average(:rating)&.to_f&.round(2), count: count }
  end

  def previous_range
    since, till = params.values_at(:prev_since, :prev_until)
    return unless since.present? && till.present?

    Time.zone.at(since.to_i)..Time.zone.at(till.to_i)
  end

  # ── Órdenes y proyectos (lo que ya calculan sus reportes) ─────────────────────

  def work_orders
    @work_orders ||= begin
      report = V2::Reports::Cases::WorkOrderBuilder.new(account: account, params: params).build
      report[:summary].slice(:open_count, :overdue_visits_count, :to_schedule_count, :awaiting_signoff_count,
                             :finished_count, :on_time_rate)
    end
  end

  def projects
    @projects ||= begin
      report = V2::Reports::Cases::ProjectBuilder.new(account: account, params: params).build
      report[:summary].slice(:open_count, :late_count, :at_risk_count, :over_budget_count, :overdue_milestones_count)
    end
  end

  # ── Personas: quién tiene más vencido (de cualquier clase) ────────────────────

  def overdue_open
    today = Time.zone.today
    pending = filtered_tickets.where(status: CaseTicket::PENDING_STATUSES)
    pending.with_capability(:sla).overdue
           .or(pending.of_class('commercial').where(expected_close_at: ...today))
           .or(pending.of_class('project').where(project_due_on: ...today))
  end

  def people
    counts = overdue_open.where.not(assignee_id: nil).group(:assignee_id).count
    names = account.users.where(id: counts.keys).pluck(:id, :name).to_h
    most = counts.sort_by { |id, n| [-n, names[id].to_s] }.first(TOP)
    { most_overdue: most.map { |id, n| { assignee_id: id, assignee_name: names[id], count: n } } }
  end

  # ── Lo que necesita tu atención ───────────────────────────────────────────────

  # Lo más grave primero: dinero prometido que no llegó, clientes con SLA vencido,
  # visitas que no se hicieron, proyectos atrasados y, al final, pronósticos viejos.
  def attention(classes)
    ATTENTION_ORDER.filter_map { |key, case_class| attention_item(key, case_class) if classes.include?(case_class) }
                   .select { |i| i[:count].positive? }.first(ATTENTION_LIMIT)
  end

  def attention_item(key, case_class)
    case key
    when 'promises_overdue'
      overdue = pipeline[:summary][:commitments][:overdue]
      item(key, case_class, overdue.sum { |v| v[:count].to_i }, values: overdue)
    when 'unattended_conversations' then item(key, case_class, conversations_block[:now][:unattended])
    when 'sla_overdue' then item(key, case_class, support[:sla_overdue])
    when 'visits_overdue' then item(key, case_class, work_orders[:overdue_visits_count])
    when 'projects_late' then item(key, case_class, projects[:late_count])
    else item(key, case_class, close_overdue_count)
    end
  end

  # Cierres estimados vencidos SIN compromiso (las promesas ya van arriba).
  def close_overdue_count
    filtered_tickets.commercial.where(status: CaseTicket::PENDING_STATUSES, committed_at: nil)
                    .where(expected_close_at: ...Time.zone.today).count
  end

  def item(key, case_class, count, values: nil)
    { key: key, case_class: case_class, count: count.to_i, values: values }.compact
  end
end
