# frozen_string_literal: true

# @tickets_cases — Consulta de la bandeja de tareas a nivel cuenta (F1), separada
# del controller para no inflarlo. Ver Api::V1::Accounts::CaseTasksIndexController
# para el contrato completo de `item_type`/filtros/orden.
#
# `item_type` decide qué se lista: '' (default) fusiona tareas (CaseTask) y
# reuniones (CaseMeeting, "tareas agendadas" en el resto del código) en un solo
# feed ordenado por fecha; 'task' u 'meeting' devuelve solo uno de los dos, con
# paginación/orden 100% en SQL (comportamiento de siempre). El conocimiento de
# cómo filtrar/ordenar cada tipo vive en TaskScope/MeetingScope, más abajo; esta
# clase solo orquesta (elige la rama, fusiona, pagina).
#
# La fusión sin filtro de tipo se hace EN MEMORIA (no con UNION SQL): esta
# bandeja es por agente/cuenta, no un feed masivo, y así se evita duplicar toda
# la lógica de filtros en SQL crudo por una ganancia de escala que no hace falta
# aquí.
#
# Devuelve { rows:, total:, page: }, donde `rows` es un array de pares
# `[record, :task | :meeting]` ya paginado — la serialización (task_json /
# meeting_json) queda del lado del controller, que es quien tiene los helpers
# de referencia (ref_user, ticket_context, el concern de reuniones).
class Cases::TasksInboxQuery
  PER_PAGE = 25

  MERGE_SORTABLE_FIELDS = %w[sequence title priority requester assignee due_at status ticket].freeze

  def initialize(account:, current_user:, params:)
    @params = params
    @task_scope = TaskScope.new(account: account, current_user: current_user, params: params)
    @meeting_scope = MeetingScope.new(account: account, current_user: current_user, params: params)
  end

  def call
    case params[:item_type]
    when 'meeting' then paginate_single(@meeting_scope, :meeting)
    when 'task' then paginate_single(@task_scope, :task)
    else merged_page
    end
  end

  private

  attr_reader :params

  def page
    @page ||= [params[:page].to_i, 1].max
  end

  def paginate_single(builder, kind)
    scope = builder.filtered
    total = scope.count
    rows  = builder.sorted(scope)
                   .includes(*builder.includes, case_ticket: :case_type)
                   .limit(PER_PAGE)
                   .offset((page - 1) * PER_PAGE)
                   .map { |record| [record, kind] }
    { rows: rows, total: total, page: page }
  end

  def merged_page
    tasks = @task_scope.filtered.includes(*@task_scope.includes, case_ticket: :case_type).to_a
    meetings = @meeting_scope.filtered.includes(*@meeting_scope.includes, case_ticket: :case_type).to_a

    merged = sort_merged(tasks.map { |t| [t, :task] } + meetings.map { |m| [m, :meeting] })
    total  = merged.size
    rows   = merged.drop((page - 1) * PER_PAGE).first(PER_PAGE)

    { rows: rows, total: total, page: page }
  end

  def sort_merged(rows)
    field = MERGE_SORTABLE_FIELDS.include?(params[:sort_by].to_s) ? params[:sort_by].to_s : 'due_at'
    desc  = params[:sort_order] == 'desc'

    decorated = rows.map { |record, kind| [merge_sort_value(record, kind, field), record, kind] }
    present, blank = decorated.partition { |value, _, _| !value.nil? }
    present.sort_by! { |value, _, _| value }
    present.reverse! if desc
    (present + blank).map { |_, record, kind| [record, kind] }
  end

  def merge_sort_value(record, kind, field)
    (kind == :task ? @task_scope : @meeting_scope).sort_value(record, field)
  end
end

# --- tareas -----------------------------------------------------------------
class Cases::TasksInboxQuery::TaskScope
  SORTABLE_COLUMNS = {
    'sequence' => 'case_tasks.sequence',
    'title' => 'case_tasks.title',
    'priority' => 'case_tasks.priority',
    'status' => 'case_tasks.status',
    'due_at' => 'case_tasks.due_at',
    'ticket' => 'case_tickets.folio',
    'assignee' => 'assignee_users.name',
    'requester' => 'requester_users.name'
  }.freeze

  SORT_VALUES = {
    'sequence' => ->(t) { t.sequence },
    'title' => ->(t) { t.title&.downcase },
    'priority' => ->(t) { t.priority },
    'requester' => ->(t) { t.requester&.name&.downcase },
    'assignee' => ->(t) { t.assignee&.name&.downcase },
    'due_at' => ->(t) { t.due_at },
    'status' => ->(t) { t.status },
    'ticket' => ->(t) { t.case_ticket&.folio }
  }.freeze

  def initialize(account:, current_user:, params:)
    @account = account
    @current_user = current_user
    @params = params
  end

  def includes
    %i[assignee requester]
  end

  # Aplica los filtros de la bandeja (todos opcionales salvo el default de asignado).
  def filtered
    scope = filter_assignee(base_scope)
    scope = filter_requester(scope)
    scope = filter_status(scope)
    scope = filter_due(scope)
    scope = filter_case_type(scope)
    filter_search(scope)
  end

  def sorted(scope)
    key = params[:sort_by].to_s
    return scope.ordered unless SORTABLE_COLUMNS.key?(key)

    dir = params[:sort_order] == 'desc' ? 'DESC' : 'ASC'
    sort_joins(scope, key).reorder(Arel.sql("#{SORTABLE_COLUMNS[key]} #{dir} NULLS LAST, case_tasks.id ASC"))
  end

  def sort_value(task, field)
    SORT_VALUES[field]&.call(task)
  end

  private

  attr_reader :account, :current_user, :params

  def base_scope
    CaseTask.where(account_id: account.id)
  end

  # assignee_id: ausente → mis tareas · 'all' → todos los agentes (sin filtro) ·
  # 'unassigned' → huérfanas · id → ese agente.
  def filter_assignee(scope)
    raw = params[:assignee_id].presence

    return scope if raw == 'all'
    return scope.where(assignee_id: nil) if raw == 'unassigned'
    return scope.where(assignee_id: current_user.id) if raw.nil?

    scope.where(assignee_id: raw)
  end

  # requester_id: quién dio de alta la tarea. Ausente → sin filtro.
  def filter_requester(scope)
    raw = params[:requester_id].presence

    return scope if raw.nil?
    return scope.where(requester_id: nil) if raw == 'unassigned'

    scope.where(requester_id: raw)
  end

  # status: ausente → pending · 'done' → completadas · 'all'/'' → todas.
  def filter_status(scope)
    raw = params[:status]

    return scope if ['all', ''].include?(raw)
    return scope.where(status: CaseTask.statuses[raw]) if CaseTask.statuses.key?(raw)

    scope.pending
  end

  # due: overdue (vencidas y aún pendientes) · today · week (próximos 7 días).
  def filter_due(scope)
    case params[:due]
    when 'overdue'
      scope.pending.where('case_tasks.due_at < ?', Time.current)
    when 'today'
      scope.where(due_at: Time.zone.today.all_day)
    when 'week'
      scope.where(due_at: Time.zone.today.beginning_of_day..6.days.from_now.end_of_day)
    else
      scope
    end
  end

  def filter_case_type(scope)
    return scope if params[:case_type_id].blank?

    scope.joins(:case_ticket).where(case_tickets: { case_type_id: params[:case_type_id] })
  end

  def filter_search(scope)
    return scope if params[:q].blank?

    like = "%#{params[:q].to_s.strip}%"
    scope.where('case_tasks.title ILIKE :q OR case_tasks.description ILIKE :q', q: like)
  end

  # Las columnas que viven en otra tabla necesitan su join (alias propio para
  # no chocar con el join de `filter_case_type`).
  def sort_joins(scope, key)
    case key
    when 'ticket' then scope.joins(:case_ticket)
    when 'assignee' then scope.joins('LEFT JOIN users AS assignee_users ON assignee_users.id = case_tasks.assignee_id')
    when 'requester' then scope.joins('LEFT JOIN users AS requester_users ON requester_users.id = case_tasks.requester_id')
    else scope
    end
  end
end

# --- reuniones ("tareas agendadas") ------------------------------------------
class Cases::TasksInboxQuery::MeetingScope
  SORTABLE_COLUMNS = {
    'sequence' => 'case_meetings.sequence',
    'title' => 'case_meetings.title',
    'status' => 'case_meetings.status',
    'due_at' => 'case_meetings.starts_at',
    'ticket' => 'case_tickets.folio',
    'assignee' => 'organizer_users.name'
  }.freeze

  # Reuniones no tienen prioridad ni solicitante propios (van al final, NULLS
  # LAST, igual que una tarea sin dato): "due_at" es su `starts_at`.
  SORT_VALUES = {
    'sequence' => ->(m) { m.sequence },
    'title' => ->(m) { m.title&.downcase },
    'assignee' => ->(m) { m.organizer&.name&.downcase },
    'due_at' => ->(m) { m.starts_at },
    'status' => ->(m) { m.status },
    'ticket' => ->(m) { m.case_ticket&.folio }
  }.freeze

  # @tickets_cases — mapeo de status de CaseMeeting a pendiente/completada
  # (decisión de producto): agendada a futuro = pendiente; cualquier otro
  # desenlace (realizada, no asistió, cancelada, reprogramada) = completada.
  PENDING_STATUSES = %w[scheduled].freeze
  DONE_STATUSES = %w[held no_show cancelled rescheduled].freeze

  def initialize(account:, current_user:, params:)
    @account = account
    @current_user = current_user
    @params = params
  end

  def includes
    [:organizer]
  end

  def filtered
    scope = filter_assignee(base_scope)
    scope = filter_requester(scope)
    scope = filter_status(scope)
    scope = filter_due(scope)
    scope = filter_case_type(scope)
    filter_search(scope)
  end

  def sorted(scope)
    key = params[:sort_by].to_s
    return scope.ordered unless SORTABLE_COLUMNS.key?(key)

    dir = params[:sort_order] == 'desc' ? 'DESC' : 'ASC'
    sort_joins(scope, key).reorder(Arel.sql("#{SORTABLE_COLUMNS[key]} #{dir} NULLS LAST, case_meetings.id ASC"))
  end

  def sort_value(meeting, field)
    SORT_VALUES[field]&.call(meeting)
  end

  private

  attr_reader :account, :current_user, :params

  def base_scope
    CaseMeeting.where(account_id: account.id)
  end

  # assignee_id → organizer_id: mismo criterio que tareas (ausente → yo,
  # 'all' → todos, 'unassigned' → sin organizador).
  def filter_assignee(scope)
    raw = params[:assignee_id].presence

    return scope if raw == 'all'
    return scope.where(organizer_id: nil) if raw == 'unassigned'
    return scope.where(organizer_id: current_user.id) if raw.nil?

    scope.where(organizer_id: raw)
  end

  # CaseMeeting no tiene solicitante: si se pide un filtro explícito, ninguna
  # reunión lo cumple (no se inventa un mapeo).
  def filter_requester(scope)
    params[:requester_id].present? ? scope.none : scope
  end

  def filter_status(scope)
    raw = params[:status]

    return scope if ['all', ''].include?(raw)
    return scope.where(status: DONE_STATUSES) if raw == 'done'

    scope.where(status: PENDING_STATUSES)
  end

  def filter_due(scope)
    case params[:due]
    when 'overdue'
      scope.where(status: PENDING_STATUSES).where('case_meetings.starts_at < ?', Time.current)
    when 'today'
      scope.where(starts_at: Time.zone.today.all_day)
    when 'week'
      scope.where(starts_at: Time.zone.today.beginning_of_day..6.days.from_now.end_of_day)
    else
      scope
    end
  end

  def filter_case_type(scope)
    return scope if params[:case_type_id].blank?

    scope.joins(:case_ticket).where(case_tickets: { case_type_id: params[:case_type_id] })
  end

  def filter_search(scope)
    return scope if params[:q].blank?

    like = "%#{params[:q].to_s.strip}%"
    scope.where('case_meetings.title ILIKE :q OR case_meetings.description ILIKE :q', q: like)
  end

  def sort_joins(scope, key)
    case key
    when 'ticket' then scope.joins(:case_ticket)
    when 'assignee' then scope.joins('LEFT JOIN users AS organizer_users ON organizer_users.id = case_meetings.organizer_id')
    else scope
    end
  end
end
