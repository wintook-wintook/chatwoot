# frozen_string_literal: true

# Asistente (Dali) — el trabajo en campo platicando (visitas de órdenes de trabajo y
# visitas agendadas sin orden, las mismas de «Mi ruta», Field::Route).
#
#   my_route(day)                 → las visitas del día del usuario, en orden de hora
#   get_visit(kind, id)           → detalle: dirección, qué hay que hacer, la lista de la orden,
#                                   lo ya anotado y las últimas visitas al cliente
#   propose_on_my_way             → tarjeta «Voy en camino» (aviso al cliente con hora estimada)
#   propose_visit_report          → el reporte dictado: en la orden, nota en la bitácora y puntos
#                                   de la lista hechos; en la visita agendada, reporte de cierre y
#                                   la visita queda realizada (Assistant::FieldRunner)
# «Llegué» (ubicación), fotos, firma y terminar la orden se quedan en el portal de campo.
# kind: 'order' (id = la orden) | 'visit' (id = la tarea agendada). Se incluye en Assistant::Tools.
module Assistant::FieldTools
  FIELD_READ_TOOLS = %w[my_route get_visit].freeze
  FIELD_PROPOSAL_TOOLS = %w[propose_on_my_way propose_visit_report].freeze
  PREVIOUS_VISITS = 3

  def tool_my_route(args)
    day = (Date.parse(args['day'].to_s) rescue nil) || Time.current.in_time_zone(@zone).to_date # rubocop:disable Style/RescueModifier
    visits = Field::Route.new(cases, @user, day, @zone).visits
    { day: day.to_s, visits: visits.map { |v| route_row(v) } }
  end

  def tool_get_visit(args)
    args['kind'] == 'visit' ? agenda_visit_detail(field_meeting(args['id'])) : order_visit_detail(field_order(args['id']))
  end

  def prepare_on_my_way(args)
    minutes = args['eta_minutes'].to_i.clamp(5, 240)
    target = field_target(args)
    [{ 'kind' => target[:kind], 'id' => target[:id], 'eta_minutes' => minutes },
     { 'rows' => [['VISIT', target[:label]], ['CLIENT', target[:client]]].select(&:last), 'eta_minutes' => minutes }]
  end

  def prepare_visit_report(args)
    raise ArgumentError, 'Falta lo que se hizo en la visita.' if args['notes'].blank?

    target = field_target(args)
    payload = { 'kind' => target[:kind], 'id' => target[:id], 'notes' => args['notes'].to_s.strip }
    labels = { 'rows' => [['VISIT', target[:label]], ['CLIENT', target[:client]]].select(&:last) }
    return order_report(target[:record], args, payload, labels) if target[:kind] == 'order'

    minutes = args['minutes'].to_i.positive? ? args['minutes'].to_i : TaskReport.suggested_minutes(target[:record])
    [payload.merge('minutes' => minutes), labels.merge('minutes' => minutes, 'closes_visit' => true)]
  end

  # La orden o la tarea agendada, con permiso de escribir (lo mismo que pide el portal).
  def field_target(args)
    if args['kind'] == 'visit'
      meeting = field_meeting(args['id'])
      return { kind: 'visit', id: meeting.id, record: meeting, label: meeting.title, client: meeting.client_contact&.name }
    end
    order = field_order(args['id'])
    raise ArgumentError, 'No puedes modificar esa orden.' unless @grant.case_writable?(order)

    { kind: 'order', id: order.id, record: order, label: "#{order.folio} · #{order.title}", client: order.contact&.name }
  end

  def field_order(id)
    order = cases.find(id)
    raise ArgumentError, 'Ese caso no es una orden de trabajo.' unless order.work_order?

    order
  end

  # Visitas agendadas: las que organiza el usuario o las de un caso que ve.
  def field_meeting(id)
    @account.case_meetings.where(is_visit: true)
            .where('case_meetings.organizer_id = :me OR case_meetings.case_ticket_id IN (:visible)', me: @user.id, visible: cases.select(:id))
            .find(id)
  end

  private

  def order_report(order, args, payload, labels)
    pending = order.case_tasks.where.not(status: :done).order(:position, :id)
    chosen = Array(args['done_task_ids']).map(&:to_i) & pending.ids
    checklist = pending.map { |t| { 'id' => t.id, 'title' => t.title, 'required' => t.required, 'checked' => chosen.include?(t.id) } }
    [payload.merge('done_task_ids' => chosen), labels.merge('checklist' => checklist)]
  end

  def route_row(visit)
    { kind: visit[:kind], id: visit[:kind] == 'visit' ? visit.dig(:meeting, :id) : visit[:id], folio: visit[:folio],
      title: visit[:title], client: visit.dig(:contact, :name) || visit[:organization], address: visit[:work_address],
      starts_at: local(visit.dig(:meeting, :starts_at)), state: visit[:state] }.compact
  end

  def order_visit_detail(order)
    data = Field::VisitSerializer.new(order, @user).as_json
    { kind: 'order', id: order.id, folio: order.folio, title: order.title, state: data[:state], address: order.work_address,
      client: order.contact && contact_ref(order.contact), description: order.description.to_s.truncate(400),
      materials: data[:items], previous_visits: previous_visits(order.contact, order.id) }.merge(report_detail(data[:report]))
  end

  def report_detail(report)
    { checklist: report[:checklist].map { |t| t.slice(:id, :title, :required, :status) },
      notes_so_far: report[:logs].select { |l| l[:kind] == 'note' }.last(5).map { |l| l[:content].to_s.truncate(200) },
      missing_to_finish: report[:missing] }
  end

  def agenda_visit_detail(meeting)
    data = Field::AgendaVisitSerializer.new(meeting).as_json
    { kind: 'visit', id: meeting.id, title: meeting.title, state: data[:state], address: meeting.location,
      starts_at: local(meeting.starts_at), description: meeting.description.to_s.truncate(400),
      client: meeting.client_contact && contact_ref(meeting.client_contact), case: meeting.case_ticket&.folio,
      previous_visits: previous_visits(meeting.client_contact, nil) }.compact
  end

  # «¿Qué le hicimos la última vez?»: sus últimas órdenes de trabajo terminadas y su nota final.
  def previous_visits(contact, except_id)
    return [] unless contact

    orders = cases.where(contact_id: contact.id, case_type_id: CaseType.where(case_class: :work_order).select(:id))
                  .where.not(id: except_id).where(status: ServiceReportable::COMPLETION_STATUSES)
                  .order(updated_at: :desc).limit(PREVIOUS_VISITS)
    orders.map do |o|
      { folio: o.folio, title: o.title, date: local(o.updated_at),
        notes: o.work_logs.note.ordered.last(3).map { |l| l.content.to_s.truncate(200) } }
    end
  end
end
