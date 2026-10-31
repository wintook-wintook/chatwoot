# Plan-Trabajo-Campo R3 — tablero de despacho de un día: una columna por técnico
# con sus visitas (y los choques de horario), las visitas sin técnico y las
# órdenes en campo que todavía no tienen visita.
class Field::DispatchBoard
  # `zone`: la del usuario. El día se cuenta en su hora, no en la del servidor (UTC).
  def initialize(account, scope, day, zone = Time.zone)
    @account = account
    @scope = scope
    @day = day
    @hours = day.in_time_zone(zone).all_day
  end

  def build
    meetings = day_meetings
    {
      day: @day,
      technicians: technicians(meetings).map { |user| technician_json(user, meetings) },
      unassigned: meetings.select { |m| m.case_ticket.assignee_id.nil? }.map { |m| visit_json(m) },
      unscheduled: unscheduled_orders.map { |order| order_json(order) },
      salespeople: salespeople
    }
  end

  private

  # Visitas — las tareas agendadas marcadas como visita, una columna por persona.
  def salespeople
    agenda_visits.group_by(&:organizer).filter_map do |user, visits|
      next if user.nil?

      { id: user.id, name: user.name, skills: [], zone: nil, visits: visits.map { |m| agenda_visit_json(m) }, conflicts: conflicts(visits) }
    end
  end

  def agenda_visits
    CaseMeeting.active.where(account_id: @account.id, is_visit: true, starts_at: @hours)
               .includes(:organizer, :contact, :organization, case_ticket: %i[contact organization case_type])
               .order(:starts_at).reject { |meeting| meeting.case_ticket&.work_order? }
  end

  def agenda_visit_json(meeting)
    visit = Field::AgendaVisitSerializer.new(meeting).summary
    visit.merge(contact: visit[:contact]&.fetch(:name), meeting: visit[:meeting])
  end

  def field_orders
    @scope.where(case_type_id: CaseType.where(case_class: :work_order).select(:id)).where.not(status: %w[closed cancelled])
  end

  def day_meetings
    CaseMeeting.active.where(case_ticket_id: field_orders.select(:id), starts_at: @hours)
               .includes(case_ticket: %i[contact case_type assignee]).order(:starts_at)
               .select { |meeting| meeting.case_ticket.on_site_effective }
  end

  def unscheduled_orders
    # Sin las de la agenda: un case_ticket_id nulo dejaría vacío el NOT IN de abajo.
    upcoming = CaseMeeting.active.where(starts_at: Time.current.beginning_of_day..).where.not(case_ticket_id: nil).select(:case_ticket_id)
    field_orders.where.not(id: upcoming).where.not(status: ServiceReportable::COMPLETION_STATUSES)
                .includes(:contact, :case_type, :assignee).order(:created_at).limit(100)
                .select(&:on_site_effective)
  end

  # Los técnicos (rol Técnico o con perfil de campo) y quien tenga visitas ese día.
  def technicians(meetings)
    tech_role = @account.access_roles.find_by(key: 'technician')
    account_users = @account.account_users.includes(:user)
    ids = account_users.select { |au| (tech_role && au.access_role_id == tech_role.id) || au.field_profile.present? }.map(&:user_id)
    ids |= meetings.filter_map { |m| m.case_ticket.assignee_id }
    @profiles = account_users.to_h { |au| [au.user_id, au.field_profile] }
    @account.users.where(id: ids).order(:name)
  end

  def technician_json(user, meetings)
    own = meetings.select { |m| m.case_ticket.assignee_id == user.id }
    profile = @profiles[user.id] || {}
    { id: user.id, name: user.name, skills: Array(profile['skills']), zone: profile['zone'],
      visits: own.map { |m| visit_json(m) }, conflicts: conflicts(own) }
  end

  # Visitas que se enciman con la anterior del mismo técnico.
  def conflicts(meetings)
    meetings.each_cons(2).filter_map { |prev, current| current.id if current.starts_at < (prev.ends_at || prev.starts_at) }
  end

  def visit_json(meeting)
    order_json(meeting.case_ticket).merge(meeting: { id: meeting.id, starts_at: meeting.starts_at, ends_at: meeting.ends_at },
                                          customer_response: customer_response(meeting))
  end

  # Plan-Trabajo-Campo R5 — lo que contestó el cliente de esta visita (confirmed / reschedule).
  def customer_response(meeting)
    response = meeting.case_ticket.visit_response || {}
    return unless response['meeting_id'] == meeting.id && response['starts_at'] == meeting.starts_at.iso8601

    response.slice('status', 'preferred', 'note')
  end

  def order_json(order)
    { id: order.id, folio: order.folio, title: order.title, status: order.status, work_address: order.work_address,
      case_type: order.case_type&.name, contact: order.contact&.name,
      assignee: order.assignee && { id: order.assignee.id, name: order.assignee.name } }
  end
end
