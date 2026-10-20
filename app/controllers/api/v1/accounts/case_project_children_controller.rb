# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Clase-Proyecto P2: casos dentro de un proyecto
# ================================================================================
# GET    /api/v1/accounts/:id/case_tickets/:case_ticket_id/project_children
# POST   /api/v1/accounts/:id/case_tickets/:case_ticket_id/project_children
#          { case_type_id, title? }  → crea una orden o un ticket dentro del proyecto
#          { ticket_id }             → liga un caso que ya existe
# GET    /api/v1/accounts/:id/case_tickets/:case_ticket_id/project_children/timeline
#          → línea de tiempo (P3): hitos y casos hijos con fecha, más inicio, objetivo y hoy
# DELETE /api/v1/accounts/:id/case_tickets/:case_ticket_id/project_children/:id
#          (id = el caso hijo) → lo saca del proyecto (el caso no se borra)
#
# Hijos = órdenes de trabajo y tickets de Soporte (decisión 3), uno por proyecto, por
# la relación `project_member` (hijo → proyecto). Deja `related` en los dos casos.
# ================================================================================

class Api::V1::Accounts::CaseProjectChildrenController < Api::V1::Accounts::BaseController
  before_action :set_project

  def index
    render json: { project_children: @project.project_children.includes(:case_type, :assignee).order(:created_at)
                                             .map { |t| child_json(t) } }
  end

  def create
    return render_error('El proyecto está cerrado: reábrelo para agregar casos') if @project.frozen_for_edit?

    child = params[:ticket_id].present? ? existing_child : new_child
    return if performed?

    link!(child)
    render json: { project_child: child_json(child) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.to_sentence)
  end

  # Plan-Clase-Proyecto P3 — cada elemento con su fecha: el hito por su vencimiento,
  # la orden por su próxima visita (si no, su vencimiento) y el ticket por su
  # vencimiento. Sin fecha no entra a la línea (se lista aparte en la pestaña).
  def timeline
    render json: {
      start_on: @project.project_start_on || @project.created_at.to_date,
      due_on: @project.project_due_on,
      today: Date.current,
      items: (milestone_items + child_items).sort_by { |item| item[:date] }
    }
  end

  def destroy
    relation = CaseTicketRelation.project_member.find_by(ticket_id: params[:id], related_ticket_id: @project.id)
    return render json: { error: 'El caso no está en este proyecto' }, status: :not_found unless relation

    relation.destroy
    head :no_content
  end

  private

  def set_project
    @project = Current.account.case_tickets.find(params[:case_ticket_id])
    render_error('Solo un proyecto tiene casos dentro') unless @project.project?
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Proyecto no encontrado' }, status: :not_found
  end

  def existing_child
    child = Current.account.case_tickets.find_by(id: params[:ticket_id])
    return render_error('Caso no encontrado') unless child
    return render_error('Solo órdenes de trabajo y tickets de Soporte van dentro de un proyecto') unless child_class?(child)
    return render_error('Ese caso ya pertenece a un proyecto') if child.parent_project

    child
  end

  def new_child
    case_type = Current.account.case_types.find_by(id: params[:case_type_id])
    unless case_type && CaseTicket::PROJECT_CHILD_CLASSES.include?(case_type.case_class)
      return render_error('Elige un tipo de orden de trabajo o de Soporte')
    end

    attrs = { case_type_id: case_type.id, title: params[:title].presence || @project.title }
    if @project.contact
      Cases::OrchestratorService.new(account: Current.account, contact: @project.contact,
                                     conversation: @project.conversation).create_for_manual(**attrs)
    else
      Cases::OrchestratorService.new(account: Current.account).create_internal(requester: current_user, **attrs)
    end
  end

  def child_class?(ticket)
    CaseTicket::PROJECT_CHILD_CLASSES.include?(ticket.case_type&.case_class || 'support')
  end

  def link!(child)
    ActiveRecord::Base.transaction do
      CaseTicketRelation.create!(account: Current.account, ticket: child, related_ticket: @project,
                                 relation_type: :project_member)
      log_related(child, @project)
      log_related(@project, child)
    end
  end

  def log_related(ticket, other)
    ticket.case_events.create!(
      account: Current.account, event_type: :related, origin: :agent, actor: current_user,
      payload: { relation_type: 'project_member', related_folio: other.folio, related_title: other.title,
                 related_ticket_id: other.id }.compact
    )
  end

  def milestone_items
    @project.case_tasks.where(milestone: true).where.not(due_at: nil).map do |task|
      { kind: 'milestone', id: task.id, title: task.title, date: task.due_at.to_date, done: task.done?,
        overdue: !task.done? && task.due_at < Time.current }
    end
  end

  def child_items
    @project.project_children.includes(:case_type).filter_map do |child|
      date = child_date(child)
      date && child_item(child, date)
    end
  end

  # La orden por su próxima visita (si no, su vencimiento); el ticket por su vencimiento.
  def child_date(child)
    (child.next_visit_at if child.work_order?) || child.due_at
  end

  def child_item(child, date)
    done = CaseTicket::PROGRESS_DONE_STATUSES.include?(child.status)
    { kind: 'case', id: child.id, folio: child.folio, title: child.title, date: date.to_date, done: done,
      case_class: child.case_type&.case_class || 'support', overdue: !done && date < Time.current }
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  def child_json(ticket)
    {
      id: ticket.id,
      folio: ticket.folio,
      title: ticket.title,
      status: ticket.status,
      case_class: ticket.case_type&.case_class || 'support',
      case_type: type_ref(ticket.case_type),
      assignee: ticket.assignee && { id: ticket.assignee.id, name: ticket.assignee.name }
    }.merge(child_dates(ticket))
  end

  def type_ref(type)
    type && { id: type.id, name: type.name, color: type.color }
  end

  def child_dates(ticket)
    { actual_hours: ticket.actual_hours&.to_f, estimated_hours: ticket.estimated_hours&.to_f,
      next_visit_at: (ticket.next_visit_at if ticket.work_order?), due_at: ticket.due_at }
  end
end
