# Las tareas pendientes de un caso que se cierra: se cancelan o, si quien cierra lo pide,
# siguen vivas sin caso, en el contacto y en Mi día. Las de «Documenta…» dependen de la etapa
# del caso: esas siempre se cancelan. Las tareas agendadas que ya pasaron sin marcarse también
# se cancelan, sin avisar a nadie; las futuras las decide quien cierra (`cancel_meetings`).
class Cases::PendingTasksOnClose
  REASON = 'case_closed'.freeze

  def initialize(ticket, keep: false)
    @ticket = ticket
    @keep = keep
  end

  def call
    tasks = @ticket.case_tasks.pending.to_a
    past = cancel_past_meetings
    kept, cancelled = @keep ? tasks.partition { |task| task.documentation_for_column_id.nil? } : [[], tasks]
    kept.each { |task| detach(task) }
    cancel(cancelled)
    log(kept: kept.size, cancelled: cancelled.size, past: past)
  end

  private

  # Sin tocar Google: el evento ya pasó, y cancelarlo le escribiría al cliente.
  def cancel_past_meetings
    @ticket.case_meetings.active.where(starts_at: ...Time.current)
           .update_all(status: CaseMeeting.statuses[:cancelled], cancelled_at: Time.current, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def cancel(tasks)
    # Sin callbacks: cerrar el caso no debe mover etapas ni pedir reporte.
    attrs = { status: CaseTask.statuses[:cancelled], cancelled_at: Time.current, cancel_reason: REASON, updated_at: Time.current }
    CaseTask.where(id: tasks.map(&:id)).update_all(attrs) # rubocop:disable Rails/SkipsModelValidations
  end

  def detach(task)
    task.case_meetings.update_all(case_task_id: nil) # rubocop:disable Rails/SkipsModelValidations
    task.update!(case_ticket: nil, contact: @ticket.contact, organization_id: @ticket.organization_id, assignee: task.assignee || Current.user,
                 required: false, case_type_column: nil, case_type_column_task: nil, sequence: next_sequence)
  end

  def next_sequence
    (CaseTask.without_case.where(account_id: @ticket.account_id).maximum(:sequence) || 0) + 1
  end

  def log(counts)
    return if counts.values.all?(&:zero?)

    I18n.with_locale(@ticket.account.locale) do
      content = counts.select { |_, count| count.positive? }.map { |key, count| I18n.t("case_tasks.on_close.#{key}", count: count) }.join(' ')
      @ticket.case_events.create!(account_id: @ticket.account_id, event_type: :internal_note, origin: :system, actor: Current.user,
                                  payload: { content: content })
    end
  end
end
