# frozen_string_literal: true

# Tareas que se repiten — lo que toca hoy (en la zona de quien la programó):
#   - Si la vez anterior sigue pendiente, no se crea otra: en fecha fija cuenta como no hecha, se avisa al
#     responsable y a quien la programó, y se pasa a la siguiente fecha; en 'after_done' espera a que la haga.
#   - Si no, crea la tarea (o la tarea agendada, si lleva hora) para ese día y calcula la siguiente.
#   - Termina sola al pasar su fecha final o su número de veces, o si su caso ya se cerró.
# Si el job estuvo detenido varios días, crea una sola y salta las fechas que ya pasaron (no amontona).
class TaskRecurrences::Generator
  def initialize(recurrence)
    @rec = recurrence
  end

  def call
    return unless due?
    return finish! if finished?(@rec.next_on)

    pending = @rec.pending_item
    pending ? missed(pending) : generate
  end

  private

  def due?
    return false unless @rec.status == 'active'

    schedule_after_done if !@rec.fixed? && @rec.next_on.nil?
    @rec.next_on.present? && @rec.next_on <= @rec.today
  end

  def schedule_after_done
    return if @rec.pending_item

    last = @rec.last_done_on
    @rec.update!(next_on: last ? [@rec.cadence.after(last), @rec.today].max : @rec.today) if last || @rec.generated_count.zero?
  end

  def missed(pending)
    return @rec.update!(next_on: nil) unless @rec.fixed?

    @rec.update!(missed_count: @rec.missed_count + 1, next_on: following(@rec.next_on))
    TaskRecurrences::Notifier.missed(@rec, pending)
  end

  def generate
    date = @rec.next_on
    item = @rec.scheduled? ? create_meeting(date) : create_task(date)
    return if item.nil?

    @rec.update!(generated_count: @rec.generated_count + 1, last_generated_on: date,
                 next_on: @rec.fixed? ? following(date) : nil)
    item
  end

  # La siguiente fecha que todavía no pasó (si el job estuvo detenido, no se cobran las de atrás).
  def following(date)
    nxt = @rec.cadence.next_after(date)
    nxt = @rec.cadence.next_after(nxt) while nxt && nxt <= @rec.today
    nxt
  end

  def finished?(date)
    (@rec.ends_on && date > @rec.ends_on) || (@rec.max_count && @rec.generated_count >= @rec.max_count) ||
      @rec.case_ticket&.status.to_s.in?(%w[closed cancelled])
  end

  def finish!
    @rec.update!(status: 'ended', next_on: nil)
  end

  def create_task(date)
    CaseTask.create!(
      account: @rec.account, case_ticket: @rec.case_ticket, contact: @rec.case_ticket ? nil : @rec.contact,
      organization_id: @rec.case_ticket ? nil : @rec.organization_id, title: @rec.title, description: @rec.description,
      assignee: @rec.assignee, requester: @rec.user, priority: @rec.priority, estimated_minutes: @rec.estimated_minutes,
      planned_on: date, due_at: @rec.zone.local(date.year, date.month, date.day).end_of_day, task_recurrence: @rec
    )
  end

  def create_meeting(date)
    starts = starts_at(date)
    attrs = { title: @rec.title, description: @rec.description, starts_at: starts, ends_at: starts + (@rec.estimated_minutes || 60).minutes }
    client = @rec.case_ticket ? { case_ticket: @rec.case_ticket } : { contact: @rec.contact, organization: @rec.organization }
    meeting = AgendaItems::Creator.new(account: @rec.account, user: @rec.user, attrs: attrs, client: client,
                                       organizer: @rec.assignee || @rec.user).call
    meeting.update_columns(task_recurrence_id: @rec.id) # rubocop:disable Rails/SkipsModelValidations
    meeting
  end

  def starts_at(date)
    hour, minute = @rec.at_time.split(':').map(&:to_i)
    @rec.zone.local(date.year, date.month, date.day, hour, minute)
  end
end
