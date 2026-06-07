# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Controller: Api::V1::Accounts::CaseTicketsController
#
# GET    /api/v1/accounts/:account_id/case_tickets              → index
# POST   /api/v1/accounts/:account_id/case_tickets              → create
# GET    /api/v1/accounts/:account_id/case_tickets/:id          → show
# PATCH  /api/v1/accounts/:account_id/case_tickets/:id/transition → transition
# PATCH  /api/v1/accounts/:account_id/case_tickets/:id/assign   → assign
#
# Filtros soportados en index:
#   q (folio/title/description/nombre de contacto), status, case_type_id, priority,
#   sla_status, assignee_id, contact_id, date_from, date_to,
#   sort_by (created_at|priority|sla_status|status), sort_order (asc|desc),
#   page, per_page
# ================================================================================

class Api::V1::Accounts::CaseTicketsController < Api::V1::Accounts::BaseController
  before_action :set_ticket, only: %i[show update transition assign escalate change_approval generate_article]

  # GET /api/v1/accounts/:account_id/case_tickets/metrics
  def metrics
    tickets = scoped_tickets_for_metrics
    open_tickets = Current.account.case_tickets.where.not(status: %w[closed cancelled])

    render json: {
      period:   { from: date_from, to: date_to },
      summary: {
        total:                      tickets.count,
        total_open:                 open_tickets.count,
        sla_overdue:                open_tickets.overdue.count,
        sla_at_risk:                open_tickets.at_risk.count,
        avg_resolution_minutes:     avg_resolution_minutes(tickets),
        avg_first_response_minutes: avg_first_response_minutes(tickets), # @tickets_cases 2J
        sla_compliance_rate:        sla_compliance_rate(tickets),
        resolved_this_period:       tickets.resolved.count + tickets.closed.count,
        reopened:                   reopened_count(tickets),            # @tickets_cases 2J
        open_problems:              open_tickets.kind_problem.count,    # @tickets_cases 2J
        pending_changes:            pending_changes_count(open_tickets), # @tickets_cases 2J
        csat_avg:                   csat_stats(tickets)[:avg],          # @tickets_cases 2J
        csat_count:                 csat_stats(tickets)[:count]
      },
      by_status:     enum_counts(tickets, :status,     CaseTicket.statuses),
      by_type:       type_counts(tickets),
      by_priority:   enum_counts(tickets, :priority,   CaseTicket.priorities),
      by_sla_status: enum_counts(tickets, :sla_status, CaseTicket.sla_statuses),
      by_category:   category_counts(tickets),  # @tickets_cases 2J
      by_service:    service_counts(tickets),   # @tickets_cases 2J
      by_assignee:   assignee_counts(tickets),  # @tickets_cases 2J
      daily:         daily_series(tickets)      # @tickets_cases 2J
    }
  end

  # GET /api/v1/accounts/:account_id/case_tickets/kb_portals
  # @tickets_cases 2H — portales + categorías para el selector de "Generar artículo".
  def kb_portals
    portals = Current.account.portals.map do |p|
      {
        id:             p.id,
        name:           p.name,
        default_locale: p.default_locale,
        categories:     p.categories.map { |c| { id: c.id, name: c.name, locale: c.locale } }
      }
    end
    render json: { portals: portals }
  end

  PER_PAGE_DEFAULT = 25
  PER_PAGE_MAX     = 100
  SORTABLE_COLUMNS = %w[created_at priority sla_status status].freeze

  # GET /api/v1/accounts/:account_id/case_tickets
  def index
    tickets = Current.account.case_tickets

    tickets = apply_search(tickets)
    tickets = tickets.where(status:       CaseTicket.statuses[params[:status]])      if params[:status].present?
    tickets = tickets.where(case_type_id: params[:case_type_id])                     if params[:case_type_id].present?
    tickets = tickets.where(ticket_kind:  CaseTicket.ticket_kinds[params[:ticket_kind]]) if params[:ticket_kind].present?
    tickets = tickets.where(affected_service_id: params[:affected_service_id])       if params[:affected_service_id].present?
    tickets = tickets.where(category_id:  params[:category_id])                       if params[:category_id].present?
    tickets = tickets.where(priority:     CaseTicket.priorities[params[:priority]])  if params[:priority].present?
    tickets = tickets.where(sla_status:  CaseTicket.sla_statuses[params[:sla_status]]) if params[:sla_status].present?
    tickets = apply_assignee(tickets)
    tickets = tickets.where(contact_id:  params[:contact_id])                        if params[:contact_id].present?
    tickets = apply_date_range(tickets)
    tickets = apply_sort(tickets)

    per_page = [[params.fetch(:per_page, PER_PAGE_DEFAULT).to_i, 1].max, PER_PAGE_MAX].min
    tickets  = tickets.page(params[:page]).per(per_page)

    render json: {
      case_tickets: tickets.map { |t| ticket_json(t) },
      meta: pagination_meta(tickets)
    }
  end

  # GET /api/v1/accounts/:account_id/case_tickets/:id
  def show
    render json: { case_ticket: ticket_json(@ticket) }
  end

  # POST /api/v1/accounts/:account_id/case_tickets
  def create
    case_type = Current.account.case_types.find_by(id: ticket_params[:case_type_id])
    custom = custom_field_values(case_type)
    missing = missing_required_fields(case_type, custom)
    if missing.any?
      return render json: { error: ["Campos requeridos: #{missing.join(', ')}"] }, status: :unprocessable_entity
    end

    ticket = Cases::OrchestratorService.new(
      account:      Current.account,
      contact:      Current.account.contacts.find(ticket_params[:contact_id]),
      conversation: resolve_conversation
    ).create_for_manual(
      case_type_id:        ticket_params[:case_type_id],
      title:               ticket_params[:title],
      priority:            ticket_params[:priority],
      description:         ticket_params[:description],
      ticket_kind:         ticket_params[:ticket_kind],
      impact:              ticket_params[:impact],
      urgency:             ticket_params[:urgency],
      affected_service_id: ticket_params[:affected_service_id],
      category_id:         ticket_params[:category_id],
      custom_attributes:   custom
    )

    render json: { case_ticket: ticket_json(ticket) }, status: :created
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /api/v1/accounts/:account_id/case_tickets/:id
  # @tickets_cases 2F — edita los campos ITIL de Problema/Cambio (custom_attributes).
  def update
    incoming = update_params[:custom_attributes]&.to_h || {}
    if incoming.key?('requires_approval')
      incoming['requires_approval'] = ActiveModel::Type::Boolean.new.cast(incoming['requires_approval'])
    end
    @ticket.update!(custom_attributes: @ticket.custom_attributes.merge(incoming))
    render json: { case_ticket: ticket_json(@ticket.reload) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /api/v1/accounts/:account_id/case_tickets/:id/transition
  def transition
    new_status = params[:status].to_s
    unless @ticket.can_transition_to?(new_status)
      return render json: {
        error: "Transición inválida: #{@ticket.status} → #{new_status}"
      }, status: :unprocessable_entity
    end

    @ticket.transition!(new_status, actor: current_user, reason: params[:reason], closure: closure_params)

    # @tickets_cases 2F — propagación opcional de la resolución de un problema a sus incidentes.
    propagated = []
    if @ticket.kind_problem? && new_status == 'resolved' &&
       ActiveModel::Type::Boolean.new.cast(params[:propagate_to_incidents])
      propagated = @ticket.propagate_resolution_to_incidents!(actor: current_user)
    end

    render json: { case_ticket: ticket_json(@ticket.reload), propagated_incidents: propagated }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /api/v1/accounts/:account_id/case_tickets/:id/change_approval
  # @tickets_cases 2F — aprueba o rechaza un cambio (status: approved|rejected).
  def change_approval
    @ticket.set_change_approval!(params[:status], actor: current_user, reason: params[:reason])
    render json: { case_ticket: ticket_json(@ticket.reload) }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /api/v1/accounts/:account_id/case_tickets/:id/assign
  def assign
    if params[:assignee_id].present?
      user = Current.account.users.find_by(id: params[:assignee_id])
      return render json: { error: 'Agente no encontrado' }, status: :not_found unless user

      @ticket.update!(assignee: user, assignee_type: :agent)
      @ticket.case_events.create!(account: Current.account, event_type: :assigned,
                                  origin: :agent, actor: current_user,
                                  payload: { assignee_id: user.id, assignee_name: user.name })
    elsif params[:team_id].present?
      team = Current.account.teams.find_by(id: params[:team_id])
      return render json: { error: 'Equipo no encontrado' }, status: :not_found unless team

      @ticket.update!(team: team, assignee_type: :team)
      @ticket.case_events.create!(account: Current.account, event_type: :assigned,
                                  origin: :agent, actor: current_user,
                                  payload: { team_id: team.id, team_name: team.name })
    else
      return render json: { error: 'Se requiere assignee_id o team_id' }, status: :unprocessable_entity
    end

    render json: { case_ticket: ticket_json(@ticket.reload) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PATCH /api/v1/accounts/:account_id/case_tickets/:id/escalate
  # @tickets_cases 2D — sube el nivel de escalamiento; reasigna a team/agente opcional.
  def escalate
    team     = params[:team_id].present?     ? Current.account.teams.find_by(id: params[:team_id]) : nil
    assignee = params[:assignee_id].present? ? Current.account.users.find_by(id: params[:assignee_id]) : nil

    @ticket.escalate!(actor: current_user, reason: params[:reason], team: team, assignee: assignee)
    render json: { case_ticket: ticket_json(@ticket.reload) }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/case_tickets/:id/generate_article
  # @tickets_cases 2H — crea un Article nativo desde el cierre y lo enlaza al ticket;
  # luego encola la vectorización (KnowledgeItemSyncJob) para que la IA (Fase 3) lo encuentre.
  def generate_article
    portal = Current.account.portals.find_by(id: params[:portal_id])
    return render json: { error: 'Selecciona un portal válido' }, status: :unprocessable_entity unless portal

    category = portal.categories.find_by(id: params[:category_id]) if params[:category_id].present?

    article = portal.articles.new(
      account:  Current.account,
      author:   current_user,
      category: category,
      title:    params[:title].presence   || @ticket.title,
      content:  params[:content].presence || default_article_content,
      status:   ActiveModel::Type::Boolean.new.cast(params[:published]) ? :published : :draft
    )
    article.locale = params[:locale] if params[:locale].present?
    article.save!

    @ticket.update!(kb_article: article)
    @ticket.case_events.create!(
      account: Current.account, event_type: :article_generated, origin: :agent, actor: current_user,
      payload: { article_id: article.id, title: article.title }
    )

    # Vectorización asíncrona (solo artículos generados desde tickets — decisión 2H).
    KnowledgeItemSyncJob.perform_later(
      action: 'upsert', source_type: 'article', source_id: article.id, account_id: Current.account.id
    )

    render json: { case_ticket: ticket_json(@ticket.reload), article: article_summary(article) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  # @tickets_cases 2H — cuerpo del artículo precargado desde el cierre documentado (2G).
  def default_article_content
    parts = []
    parts << "## Síntoma\n\n#{@ticket.description}"       if @ticket.description.present?
    parts << "## Causa\n\n#{@ticket.closure_cause}"       if @ticket.closure_cause.present?
    parts << "## Solución\n\n#{@ticket.closure_solution}" if @ticket.closure_solution.present?
    parts.join("\n\n")
  end

  def article_summary(article)
    {
      id:        article.id,
      title:     article.title,
      status:    article.status,
      slug:      article.slug,
      portal_id: article.portal_id
    }
  end

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ticket no encontrado' }, status: :not_found
  end

  def ticket_params
    params.require(:case_ticket).permit(
      :contact_id, :conversation_id, :case_type_id, :title,
      :priority, :description,
      :ticket_kind, :impact, :urgency, :affected_service_id, :category_id
    )
  end

  # @tickets_cases 2K — valores de los campos personalizados, acotados a las claves
  # definidas para el tipo de caso (ignora cualquier clave no declarada).
  def custom_field_values(case_type)
    return {} if case_type.nil?

    raw = params.dig(:case_ticket, :custom_attributes)
    return {} if raw.blank?

    permitted_keys = case_type.case_type_fields.pluck(:key)
    raw.to_unsafe_h.stringify_keys.slice(*permitted_keys)
  end

  # @tickets_cases 2K — etiquetas de los campos requeridos sin valor capturado.
  def missing_required_fields(case_type, values)
    return [] if case_type.nil?

    case_type.case_type_fields.where(required: true).ordered.filter_map do |field|
      value = values[field.key]
      blank = field.field_checkbox? ? !ActiveModel::Type::Boolean.new.cast(value) : value.to_s.strip.blank?
      field.label if blank
    end
  end

  # @tickets_cases 2G — datos de cierre documentado (nil si no vienen en el request).
  def closure_params
    return nil if params[:closure].blank?

    params[:closure].permit(:closure_type, :closure_cause, :closure_solution, :customer_confirmed).to_h
  end

  # @tickets_cases 2F — solo los campos ITIL de Problema/Cambio (approval_status excluido:
  # se controla por change_approval para mantener la auditoría).
  def update_params
    params.require(:case_ticket).permit(
      custom_attributes: (CaseTicket::PROBLEM_FIELDS + CaseTicket::CHANGE_FIELDS)
    )
  end

  def resolve_conversation
    return nil unless ticket_params[:conversation_id].present?

    Current.account.conversations.find_by(id: ticket_params[:conversation_id])
  end

  def ticket_json(ticket)
    {
      id:                         ticket.id,
      folio:                      ticket.folio,
      title:                      ticket.title,
      description:                ticket.description,
      case_type_id:               ticket.case_type_id,
      case_type:                  case_type_json(ticket.case_type),
      ticket_kind:                ticket.ticket_kind,
      impact:                     ticket.impact,
      urgency:                    ticket.urgency,
      affected_service_id:        ticket.affected_service_id,
      affected_service:           ref_json(ticket.affected_service),
      category_id:                ticket.category_id,
      category:                   ref_json(ticket.category),
      origin:                     ticket.origin,
      priority:                   ticket.priority,
      status:                     ticket.status,
      escalation_level:           ticket.escalation_level,
      requires_approval:          ticket.requires_approval?,
      change_approval_status:     ticket.change_approval_status,
      assignee_type:              ticket.assignee_type,
      sla_status:                 ticket.sla_status,
      first_response_time_target: ticket.first_response_time_target,
      resolution_time_target:     ticket.resolution_time_target,
      first_response_at:          ticket.first_response_at,
      resolved_at:                ticket.resolved_at,
      closed_at:                  ticket.closed_at,
      closure_type:               ticket.closure_type,
      closure_cause:              ticket.closure_cause,
      closure_solution:           ticket.closure_solution,
      customer_confirmed:         ticket.customer_confirmed,
      kb_article_id:              ticket.kb_article_id,
      kb_article:                 kb_article_json(ticket.kb_article),
      metadata:                   ticket.metadata,
      custom_attributes:          ticket.custom_attributes,
      created_at:                 ticket.created_at,
      updated_at:                 ticket.updated_at,
      contact_id:                 ticket.contact_id,
      conversation_id:            ticket.conversation_id,
      contact_tracking_id:        ticket.contact_tracking_id,
      assignee_id:                ticket.assignee_id,
      team_id:                    ticket.team_id,
      can_transition_to:          valid_transitions_for(ticket)
    }
  end

  def valid_transitions_for(ticket)
    CaseTicket::VALID_TRANSITIONS[ticket.status] || []
  end

  def case_type_json(type)
    return nil unless type

    {
      id:    type.id,
      name:  type.name,
      color: type.color,
      # @tickets_cases 2K — definiciones para mostrar los campos personalizados con etiqueta.
      custom_fields: type.case_type_fields.ordered.map do |f|
        { key: f.key, label: f.label, field_type: f.field_type, options: f.options, required: f.required }
      end
    }
  end

  # @tickets_cases 2B — referencia ligera para servicio afectado / categoría.
  def ref_json(record)
    return nil unless record

    { id: record.id, name: record.name }
  end

  # @tickets_cases 2H — resumen del artículo KB enlazado.
  def kb_article_json(article)
    return nil unless article

    { id: article.id, title: article.title, status: article.status, slug: article.slug, portal_id: article.portal_id }
  end

  # Búsqueda por folio / título / descripción / nombre de contacto (ILIKE).
  # LEFT JOIN con contacts (relación 1:1, no duplica filas → sin distinct).
  def apply_search(tickets)
    return tickets if params[:q].blank?

    term = "%#{params[:q].to_s.strip}%"
    tickets.left_joins(:contact).where(
      'case_tickets.folio ILIKE :q OR case_tickets.title ILIKE :q OR ' \
      'case_tickets.description ILIKE :q OR contacts.name ILIKE :q',
      q: term
    )
  end

  # Filtro por agente. 'null'/'none'/'unassigned' → tickets sin asignar (IS NULL).
  def apply_assignee(tickets)
    return tickets if params[:assignee_id].blank?

    if %w[null none unassigned 0].include?(params[:assignee_id].to_s)
      tickets.where(assignee_id: nil)
    else
      tickets.where(assignee_id: params[:assignee_id])
    end
  end

  # Rango de fechas sobre created_at (solo aplica los extremos presentes).
  def apply_date_range(tickets)
    if params[:date_from].present?
      tickets = tickets.where(case_tickets: { created_at: Date.parse(params[:date_from]).beginning_of_day.. })
    end
    if params[:date_to].present?
      tickets = tickets.where(case_tickets: { created_at: ..Date.parse(params[:date_to]).end_of_day })
    end
    tickets
  rescue ArgumentError
    tickets
  end

  # Orden configurable con whitelist (anti SQL-injection). Default created_at desc.
  def apply_sort(tickets)
    col = SORTABLE_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : 'created_at'
    dir = params[:sort_order] == 'asc' ? 'ASC' : 'DESC'
    # col y dir provienen de whitelists → seguro interpolar.
    tickets.reorder(Arel.sql("case_tickets.#{col} #{dir}"))
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      next_page:    collection.next_page,
      prev_page:    collection.prev_page,
      total_pages:  collection.total_pages,
      total_count:  collection.total_count
    }
  end

  # ── Métricas helpers ──────────────────────────────────────────
  def date_from
    params[:date_from].present? ? Date.parse(params[:date_from]) : 30.days.ago.to_date
  rescue ArgumentError
    30.days.ago.to_date
  end

  def date_to
    params[:date_to].present? ? Date.parse(params[:date_to]) : Date.today
  rescue ArgumentError
    Date.today
  end

  def scoped_tickets_for_metrics
    Current.account.case_tickets
           .where(created_at: date_from.beginning_of_day..date_to.end_of_day)
  end

  def enum_counts(tickets, column, enum_map)
    # Rails 7 puede devolver las claves del group como string del enum ("open")
    # o como entero (0) según versión/driver — cubrimos ambos casos.
    raw = tickets.group(column).count
    enum_map.keys.each_with_object({}) do |key, h|
      h[key] = raw[key] || raw[enum_map[key]] || 0
    end
  end

  # by_type usa la tabla case_types (configurable por cuenta): { name => count }
  def type_counts(tickets)
    raw = tickets.group(:case_type_id).count
    Current.account.case_types.ordered.each_with_object({}) do |type, h|
      h[type.name] = raw[type.id] || 0
    end
  end

  def avg_resolution_minutes(tickets)
    result = tickets.where(status: %w[resolved closed])
                    .where.not(resolved_at: nil)
                    .average("EXTRACT(EPOCH FROM (resolved_at - created_at)) / 60")
    result&.round(1)
  end

  def sla_compliance_rate(tickets)
    finished = tickets.where(status: %w[resolved closed])
    total    = finished.count
    return nil if total.zero?

    on_time = finished.where(sla_status: %w[on_time at_risk]).count
    ((on_time.to_f / total) * 100).round(1)
  end

  # ── @tickets_cases 2J — métricas ampliadas ────────────────────
  def avg_first_response_minutes(tickets)
    result = tickets.where.not(first_response_at: nil)
                    .average("EXTRACT(EPOCH FROM (first_response_at - created_at)) / 60")
    result&.round(1)
  end

  def reopened_count(tickets)
    CaseEvent.where(case_ticket_id: tickets.select(:id), event_type: :reopened).count
  end

  # Cambios abiertos que requieren aprobación y aún no están aprobados.
  def pending_changes_count(open_tickets)
    open_tickets.kind_change
                .where("custom_attributes->>'requires_approval' = 'true'")
                .where("COALESCE(custom_attributes->>'approval_status', 'pending') <> 'approved'")
                .count
  end

  def category_counts(tickets)
    raw = tickets.group(:category_id).count
    Current.account.case_categories.each_with_object({}) do |cat, h|
      count = raw[cat.id] || 0
      h[cat.name] = count if count.positive?
    end
  end

  def service_counts(tickets)
    raw = tickets.group(:affected_service_id).count
    Current.account.case_services.each_with_object({}) do |svc, h|
      count = raw[svc.id] || 0
      h[svc.name] = count if count.positive?
    end
  end

  def assignee_counts(tickets)
    raw = tickets.group(:assignee_id).count
    result = {}
    Current.account.users.each do |user|
      count = raw[user.id] || 0
      result[user.name] = count if count.positive?
    end
    unassigned = raw[nil] || 0
    result['— Sin asignar'] = unassigned if unassigned.positive?
    result
  end

  # Serie diaria: creados vs resueltos por día dentro del período.
  def daily_series(tickets)
    created  = tickets.group("DATE(case_tickets.created_at)").count
    resolved = tickets.where.not(resolved_at: nil).group("DATE(case_tickets.resolved_at)").count

    (date_from..date_to).map do |day|
      key = day.to_s
      { date: key, created: created[day] || created[key] || 0, resolved: resolved[day] || resolved[key] || 0 }
    end
  end

  def csat_stats(tickets)
    convo_ids = tickets.where.not(conversation_id: nil).distinct.pluck(:conversation_id)
    return { avg: nil, count: 0 } if convo_ids.blank?

    responses = Current.account.csat_survey_responses.where(conversation_id: convo_ids)
    count = responses.count
    return { avg: nil, count: 0 } if count.zero?

    { avg: responses.average(:rating)&.round(2), count: count }
  end
end
