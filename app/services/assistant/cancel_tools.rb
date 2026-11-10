# frozen_string_literal: true

# Asistente (Dali) — cancelar una tarea o tarea agendada («ya no hace falta»): tarjeta con el
# motivo (del catálogo, el que encaje con lo que dijo), comentario, tiempo dedicado y, en
# la agendada, avisarle al cliente. Al confirmar: Cases::Cancellation (Assistant::CancelRunner).
# kind: task (id de my_agenda / get_case) | meeting. Se incluye en Assistant::Tools.
module Assistant::CancelTools
  CANCEL_PROPOSAL_TOOLS = %w[propose_cancel_item].freeze

  def prepare_cancel_item(args)
    meeting = args['kind'] == 'meeting'
    item = cancel_target(args['kind'], args['id'])
    reasons = cancel_reasons
    reason = reasons.find { |r| r.label.casecmp?(args['reason'].to_s.strip) } || reasons.last
    payload = { 'kind' => meeting ? 'meeting' : 'task', 'id' => item.id, 'reason_id' => reason&.id,
                'comment' => args['comment'].to_s, 'minutes' => args['minutes'].presence&.to_i,
                'notify_client' => meeting && args['notify'] != false }
    [payload, cancel_labels(item, reasons, meeting)]
  end

  def cancel_reasons
    TaskOutcome.ensure_defaults_for(@account, purpose: 'cancel').where(active: true).to_a
  end

  def cancel_labels(item, reasons, meeting)
    { 'rows' => [['ITEM', item.title]], 'reasons' => reasons.map { |r| { id: r.id, label: r.label } },
      'work_started' => Cases::Cancellation.work_started?(item), 'meeting' => meeting }
  end

  # La tarea o tarea agendada, entre lo que el usuario ve (su caso, o suya si no tiene caso).
  def cancel_target(kind, id)
    scope = kind == 'meeting' ? @account.case_meetings : @account.case_tasks
    owner = kind == 'meeting' ? :organizer_id : :assignee_id
    scope.where(case_ticket_id: cases.select(:id)).or(scope.where(:case_ticket_id => nil, owner => @user.id)).find(id)
  end
end
