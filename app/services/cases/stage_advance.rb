# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Plantilla-Tareas-Etapa T3: avance al terminar las obligatorias
# ================================================================================
# `summary` (para el detalle del caso): etapa actual, cuántas obligatorias lleva,
# cuál es la siguiente etapa, si ya está listo para pasar y si pasar pide
# documentar. `call` (cuando cambia una tarea obligatoria): según el modo de la
# etapa, no hace nada (manual), deja la sugerencia en el detalle (sugerir) o mueve
# el caso (automático).
#
# Nunca avanza sin documentar: si la siguiente etapa cierra el caso, le pone
# resultado o lo pospone, no se mueve; se crea la tarea obligatoria «Documenta…»,
# que no se palomea a mano y se completa sola cuando el caso sale de la etapa.
#
# Siguiente etapa = la primera después de la actual que no sea solo de espera
# (Pospuesta, En espera, Pausada): una espera no es el siguiente paso del trabajo.
# ================================================================================

class Cases::StageAdvance
  WAITING = %w[waiting_on_customer waiting_on_third_party waiting_on_internal].freeze
  CLOSING = %w[resolved validating closed cancelled].freeze

  def initialize(ticket)
    @ticket = ticket
  end

  def summary
    return nil if stage.nil?

    total, done = required_counts
    return nil if total.zero?

    { stage: ref(stage), mode: stage.advance_mode, next: next_column && ref(next_column),
      required_total: total, required_done: done, ready: ready?, needs_doc: needs_doc? }
  end

  def call
    return if @ticket.frozen_for_edit? || stage.nil? || stage.advance_manual? || !ready?

    if needs_doc?
      ensure_documentation_task
    elsif stage.advance_automatic?
      move!
    else
      Cases::StageNotifier.new(@ticket).stage_ready(stage, next_column, needs_doc: false)
    end
  end

  private

  def stage
    @stage ||= @ticket.current_stage_column
  end

  def columns
    @columns ||= @ticket.case_type.case_type_columns.ordered.to_a
  end

  def next_column
    return @next_column if defined?(@next_column)

    after = columns.drop(columns.index(stage) + 1)
    @next_column = after.detect { |c| (c.statuses - WAITING).any? }
  end

  def required_tasks
    @ticket.case_tasks.where(case_type_column_id: stage.id, required: true, documentation_for_column_id: nil)
  end

  def required_counts
    @required_counts ||= [required_tasks.count, required_tasks.done.count]
  end

  def ready?
    total, done = required_counts
    total.positive? && total == done && next_column.present?
  end

  def needs_doc?
    return false if next_column.nil?

    target = target_status(next_column)
    next_column.outcome.present? || CLOSING.include?(target) ||
      (@ticket.commercial? && target == 'waiting_on_customer')
  end

  # El mismo criterio que el tablero: si la etapa cubre el estado actual, no cambia;
  # si no, el primero alcanzable en un salto o el primero de la etapa.
  def target_status(column)
    return @ticket.status if column.statuses.include?(@ticket.status)

    statuses = column.statuses
    statuses -= CaseTicket::COMMERCIAL_BLOCKED_STATUSES if @ticket.commercial?
    statuses.find { |s| @ticket.can_transition_to?(s) } || statuses.first
  end

  def move!
    from = stage
    to = next_column
    target = target_status(to)
    CaseTicket.transaction do
      reason = "Se terminaron las tareas obligatorias de «#{from.label}»"
      @ticket.transition!(target, reason: reason, force: true) unless target == @ticket.status
      @ticket.update!(case_type_column_id: to.id)
      log(:stage_advanced, from: from.label, to: to.label)
    end
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] avance de etapa del caso #{@ticket.id}: #{e.message}")
  end

  def ensure_documentation_task
    return if @ticket.case_tasks.pending.exists?(documentation_for_column_id: next_column.id)

    Cases::StageNotifier.new(@ticket).stage_ready(stage, next_column, needs_doc: true)

    @ticket.case_tasks.create!(
      account_id: @ticket.account_id, title: "Documenta para pasar a «#{next_column.label}»",
      description: 'Se completa sola cuando el caso pasa de etapa: documenta el cierre, el resultado o la fecha ' \
                   'desde «Cambiar estado» o el tablero.',
      priority: :high, required: true, assignee_id: @ticket.assignee_id, case_type_column: stage,
      documentation_for_column_id: next_column.id, position: @ticket.case_tasks.count
    )
  end

  def log(type, payload)
    @ticket.case_events.create!(account_id: @ticket.account_id, event_type: type, origin: :system, payload: payload)
  end

  def ref(column)
    { id: column.id, label: column.label }
  end
end
