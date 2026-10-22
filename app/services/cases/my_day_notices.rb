# frozen_string_literal: true

# ================================================================================
# @tickets_cases — «Tienes avisos importantes» en Mi día
# ================================================================================
# Los avisos de la campanita SIN LEER del agente, con peso:
#   high   — pone el botón en rojo: etapa lista que pide documentar, tareas nuevas
#            urgentes o que vencen hoy (o ya vencidas), caso asignado con SLA en
#            riesgo o vencido, SLA de conversación no cumplido, mención.
#   medium — el resto de lo que pide algo: etapa lista, tareas nuevas, caso o tarea
#            asignada, conversación asignada, mensaje nuevo en una asignada,
#            recordatorio de calendario.
#   low    — no se muestra aquí (solo en la campanita): tarea completada, mensaje en
#            una conversación donde solo participas, conversación nueva.
# «Enterado» es marcar el aviso como leído (la misma API de la campanita).
# ================================================================================

class Cases::MyDayNotices
  LIMIT = 50
  HIGH_TYPES = %w[sla_missed_first_response sla_missed_next_response sla_missed_resolution conversation_mention].freeze
  MEDIUM_TYPES = %w[case_stage_ready case_stage_tasks case_task_assignment case_ticket_assignment
                    conversation_assignment assigned_conversation_new_message calendar_event_reminder].freeze
  WEIGHT_ORDER = { 'high' => 0, 'medium' => 1 }.freeze

  def initialize(user:, account:)
    @user = user
    @account = account
  end

  def call
    notices = unread.filter_map { |n| notice(n) }
    notices.sort_by { |n| [WEIGHT_ORDER[n[:weight]], -n[:created_at]] }
  end

  private

  def unread
    @user.notifications.where(account_id: @account.id, read_at: nil)
         .where('snoozed_until IS NULL OR snoozed_until < ?', Time.current)
         .where(notification_type: HIGH_TYPES + MEDIUM_TYPES)
         .order(created_at: :desc).limit(LIMIT).includes(:primary_actor)
  end

  def notice(notification)
    actor = notification.primary_actor
    return nil if actor.nil?

    { id: notification.id, type: notification.notification_type, weight: weight(notification, actor),
      title: notification.push_message_title, body: notification.push_message_body,
      created_at: notification.created_at.to_i, link: link(actor) }
  rescue StandardError
    nil # un aviso con datos raros no tumba la lista
  end

  def weight(notification, actor)
    return 'high' if HIGH_TYPES.include?(notification.notification_type)

    high_case_notice?(notification, actor) ? 'high' : 'medium'
  end

  def high_case_notice?(notification, actor)
    case notification.notification_type
    when 'case_stage_ready' then notification.meta&.dig('needs_doc') == true
    when 'case_stage_tasks' then pressing_tasks?(actor, notification.meta&.dig('column_id'))
    when 'case_ticket_assignment' then %w[at_risk overdue].include?(actor.sla_status.to_s)
    else false
    end
  end

  # Tareas pendientes del agente en esa etapa que son urgentes o vencen hoy (o ya).
  def pressing_tasks?(ticket, column_id)
    tasks = ticket.case_tasks.pending.where(assignee_id: @user.id)
    tasks = tasks.where(case_type_column_id: column_id) if column_id
    tasks.priority_urgent.exists? || tasks.exists?(due_at: ..Time.current.end_of_day)
  end

  def link(actor)
    return { kind: 'case', id: actor.id, folio: actor.folio } if actor.is_a?(CaseTicket)
    return { kind: 'conversation', id: actor.display_id } if actor.is_a?(Conversation)

    { kind: 'other' }
  end
end
