# frozen_string_literal: true

# Asistente (Dali) — «reporta avance de la T003: llamé al proveedor, 20 min». Tarjeta con lo
# hecho y el tiempo; al confirmar, un reporte de avance (TaskReport progress, Assistant::
# ProgressRunner): la tarea sigue pendiente. El alcance es el de cancelar (cancel_target).
# Se incluye en Assistant::Tools.
module Assistant::ProgressTools
  PROGRESS_PROPOSAL_TOOLS = %w[propose_task_progress].freeze

  def prepare_task_progress(args)
    raise ArgumentError, 'Falta lo que se hizo.' if args['notes'].blank?

    task = progress_task(args['id'])
    minutes = args['minutes'].to_i.positive? ? args['minutes'].to_i : TaskReport.suggested_minutes(task)
    rows = [['ITEM', task.title], ['CASE', task.case_ticket&.folio]].select(&:last)
    [{ 'id' => task.id, 'notes' => args['notes'].to_s.strip, 'minutes' => minutes }, { 'rows' => rows }]
  end

  # Solo de una tarea pendiente y que no sea del cliente (esa la avanza él en su portal).
  def progress_task(id)
    task = cancel_target('task', id)
    raise ArgumentError, I18n.t('task_reports.progress_not_open') if !task.pending? || task.for_client?

    task
  end
end
