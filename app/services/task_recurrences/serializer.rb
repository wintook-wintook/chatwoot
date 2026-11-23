# frozen_string_literal: true

# Tareas que se repiten — para la pantalla: cuándo se repite, la próxima fecha y cómo va (a tiempo, tarde, no hecha).
module TaskRecurrences::Serializer
  module_function

  def list(rows, user)
    stats = stats_for(rows.map(&:id))
    rows.map { |r| json(r, user, stats[r.id] || {}) }
  end

  def one(recurrence, user)
    json(recurrence, user, stats_for([recurrence.id])[recurrence.id] || {})
  end

  FIELDS = %i[id title description priority estimated_minutes mode every unit weekdays at_time time_zone
              starts_on ends_on max_count status next_on generated_count missed_count].freeze
  MEETING_KEYS = { 'scheduled' => :pending, 'held' => :on_time, 'no_show' => :on_time }.freeze

  def json(rec, user, stats)
    rec.slice(*FIELDS).merge(links(rec)).merge(
      stats: { on_time: stats[:on_time].to_i, late: stats[:late].to_i, pending: stats[:pending].to_i, missed: rec.missed_count },
      mine: [rec.user_id, rec.assignee_id].include?(user.id)
    )
  end

  def links(rec)
    ticket = rec.case_ticket
    { assignee: ref(rec.assignee), user: ref(rec.user), contact: ref(rec.contact), organization: ref(rec.organization),
      case_ticket: ticket && { id: ticket.id, folio: ticket.folio, title: ticket.title } }
  end

  def ref(record)
    record && { id: record.id, name: record.name }
  end

  # A tiempo = concluida a más tardar el día que vencía; tarde = después. Las agendadas cuentan como a tiempo al concluirse.
  def stats_for(ids)
    return {} if ids.empty?

    out = Hash.new { |h, k| h[k] = { on_time: 0, late: 0, pending: 0 } }
    CaseTask.where(task_recurrence_id: ids).group(:task_recurrence_id)
            .pluck(:task_recurrence_id,
                   Arel.sql('COUNT(*) FILTER (WHERE status = 1 AND (due_at IS NULL OR completed_at <= due_at))'),
                   Arel.sql('COUNT(*) FILTER (WHERE status = 1 AND completed_at > due_at)'),
                   Arel.sql('COUNT(*) FILTER (WHERE status = 0)'))
            .each { |id, on_time, late, pending| out[id].merge!(on_time: on_time, late: late, pending: pending) }
    CaseMeeting.where(task_recurrence_id: ids).group(:task_recurrence_id, :status).count.each do |(id, status), n|
      key = MEETING_KEYS[status.to_s]
      out[id][key] += n if key
    end
    out
  end
end
