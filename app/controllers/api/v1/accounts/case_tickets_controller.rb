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
  before_action :set_ticket, only: %i[show transition assign]

  # GET /api/v1/accounts/:account_id/case_tickets/metrics
  def metrics
    tickets = scoped_tickets_for_metrics
    open_tickets = Current.account.case_tickets.where.not(status: %w[closed cancelled])

    render json: {
      period:   { from: date_from, to: date_to },
      summary: {
        total:                  tickets.count,
        total_open:             open_tickets.count,
        sla_overdue:            open_tickets.overdue.count,
        sla_at_risk:            open_tickets.at_risk.count,
        avg_resolution_minutes: avg_resolution_minutes(tickets),
        sla_compliance_rate:    sla_compliance_rate(tickets),
        resolved_this_period:   tickets.resolved.count + tickets.closed.count
      },
      by_status:     enum_counts(tickets, :status,     CaseTicket.statuses),
      by_type:       type_counts(tickets),
      by_priority:   enum_counts(tickets, :priority,   CaseTicket.priorities),
      by_sla_status: enum_counts(tickets, :sla_status, CaseTicket.sla_statuses)
    }
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
    ticket = Cases::OrchestratorService.new(
      account:      Current.account,
      contact:      Current.account.contacts.find(ticket_params[:contact_id]),
      conversation: resolve_conversation
    ).create_for_manual(
      case_type_id: ticket_params[:case_type_id],
      title:        ticket_params[:title],
      priority:     ticket_params[:priority],
      description:  ticket_params[:description]
    )

    render json: { case_ticket: ticket_json(ticket) }, status: :created
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
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

    @ticket.transition!(new_status, actor: current_user, reason: params[:reason])
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

  private

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ticket no encontrado' }, status: :not_found
  end

  def ticket_params
    params.require(:case_ticket).permit(
      :contact_id, :conversation_id, :case_type_id, :title,
      :priority, :description
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
      origin:                     ticket.origin,
      priority:                   ticket.priority,
      status:                     ticket.status,
      assignee_type:              ticket.assignee_type,
      sla_status:                 ticket.sla_status,
      first_response_time_target: ticket.first_response_time_target,
      resolution_time_target:     ticket.resolution_time_target,
      first_response_at:          ticket.first_response_at,
      resolved_at:                ticket.resolved_at,
      closed_at:                  ticket.closed_at,
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

    { id: type.id, name: type.name, color: type.color }
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
end
