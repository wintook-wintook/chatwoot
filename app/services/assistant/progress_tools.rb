# frozen_string_literal: true

# Asistente (Dali) — «reporta avance de la T003: llamé al proveedor, 20 min». Tarjeta con lo
# hecho y el tiempo; al confirmar, un reporte de avance (TaskReport progress, Assistant::
# ProgressRunner): la tarea sigue pendiente. El alcance es el de cancelar (cancel_target).
# Se incluye en Assistant::Tools.
module Assistant::ProgressTools
  PROGRESS_READ_TOOLS = %w[task_history].freeze
  PROGRESS_PROPOSAL_TOOLS = %w[propose_task_progress].freeze
  HISTORY_LINES = 25

  # «¿Cómo va la T004?»: el historial de la tarea (Cases::TaskHistory), resumido.
  def tool_task_history(args)
    data = Cases::TaskHistory.new(cancel_target('task', args['id']), zone: @zone).call
    task = data[:task]
    { title: task['title'], status: task['status'], due_on: due_on(task['due_at']), case: task[:case]&.dig('folio'),
      reported_minutes: task[:reported_minutes], estimated_minutes: task['estimated_minutes'],
      history: data[:items].first(HISTORY_LINES).map { |item| history_line(item) } }.compact
  end

  def prepare_task_progress(args)
    raise ArgumentError, 'Falta lo que se hizo.' if args['notes'].blank?

    task = progress_task(args['id'])
    minutes = args['minutes'].to_i.positive? ? args['minutes'].to_i : TaskReport.suggested_minutes(task)
    rows = [['ITEM', task.title], ['CASE', task.case_ticket&.folio]].select(&:last)
    [{ 'id' => task.id, 'notes' => args['notes'].to_s.strip, 'minutes' => minutes }, { 'rows' => rows }]
  end

  def history_line(item)
    payload = item[:payload] || {}
    text = payload['content'] || payload['reason'] || payload['title']
    { at: local(item[:at]), what: payload['kind'] || item[:event_type], who: item.dig(:actor, :name),
      text: text.to_s.truncate(300).presence, minutes: item.dig(:report, :minutes) }.compact
  end

  # Solo de una tarea pendiente y que no sea del cliente (esa la avanza él en su portal).
  def progress_task(id)
    task = cancel_target('task', id)
    raise ArgumentError, I18n.t('task_reports.progress_not_open') if !task.pending? || task.for_client?

    task
  end
end
