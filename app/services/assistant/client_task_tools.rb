# frozen_string_literal: true

# Asistente (Dali) — tareas con el cliente:
#   client_tasks(case_id | organization_id | contact_id | overdue) → las tareas del cliente (y las
#        visibles) con su avance, quién la completó y el enlace del portal
#   propose_client_task → tarjeta (caso, tarea, fecha, pide archivo, avisarle); al confirmar se
#        crea como tarea del cliente y, si se pidió, se le avisa con el enlace de su portal
# Solo casos que el usuario ve. Se incluye en Assistant::Tools.
module Assistant::ClientTaskTools
  CLIENT_TASK_READ_TOOLS = %w[client_tasks].freeze
  CLIENT_TASK_PROPOSAL_TOOLS = %w[propose_client_task].freeze
  CLIENT_TASK_LIMIT = 20

  def tool_client_tasks(args)
    tasks = client_task_scope(args).includes(:completed_by_contact, case_ticket: %i[contact organization])
                                   .order(Arel.sql('case_tasks.due_at ASC NULLS LAST')).limit(CLIENT_TASK_LIMIT)
    { tasks: tasks.map { |t| client_task_ref(t) }, portal_url: portal_url_for(args) }.compact
  end

  def prepare_client_task(args)
    ticket = client_task_case(args)
    [{ 'case_id' => ticket.id, 'title' => args['title'].to_s.first(255), 'description' => args['description'].to_s,
       'due_at' => due_day(args['due_at']), 'requires_file' => args['requires_file'] == true,
       'notify' => args['notify'] != false },
     { 'rows' => [['CASE', "#{ticket.folio} · #{ticket.title}"], ['CLIENT', ticket.organization&.name || ticket.contact&.name]].select(&:last) }]
  end

  def client_task_case(args)
    raise ArgumentError, 'Falta qué tiene que hacer el cliente.' if args['title'].blank?

    ticket = find_case(args)
    raise ArgumentError, 'El caso está cerrado: no se le pueden agregar tareas.' if ticket.frozen_for_edit?

    ticket
  end

  private

  def client_task_scope(args)
    filters = args.to_h.slice('organization_id', 'contact_id').compact_blank
    filters['id'] = args['case_id'] if args['case_id'].present?
    scope = CaseTask.client_facing.where(case_ticket_id: cases.where(filters).select(:id)).where.not(status: :cancelled)
    args['overdue'] == true ? scope.for_client.pending.where(due_at: ...Time.current) : scope
  end

  def client_task_ref(task)
    { id: task.id, title: task.title, who: task.for_client? ? 'cliente' : 'nosotros (visible)', status: task.status,
      in_progress: (true if task.client_status == 'in_progress'), due_at: local(task.due_at),
      completed_by: task.completed_by_contact&.name, case_id: task.case_ticket_id, case: task.case_ticket.folio,
      client: task.case_ticket.organization&.name || task.case_ticket.contact&.name }.compact
  end

  def portal_url_for(args)
    owner = if args['organization_id'].present?
              { organization_id: args['organization_id'] }
            elsif args['contact_id'].present?
              { contact_id: args['contact_id'] }
            end
    owner && @account.client_portal_links.active.find_by(owner)&.url
  end
end
