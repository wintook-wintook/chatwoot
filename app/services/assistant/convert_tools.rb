# frozen_string_literal: true

# Asistente (Dali) — tarea ↔ tarea agendada: «agenda la tarea de llamar a Mario el jueves a
# las 10» o «la visita de mañana quítala de la agenda, déjala como tarea». Tarjeta con el
# día y la hora (o el aviso al cliente) y, al confirmar, Cases::Conversion
# (Assistant::ConvertRunner). kind: task (a la agenda) | meeting (a tarea). Se incluye en
# Assistant::Tools; el alcance es el mismo de cancelar (cancel_target).
module Assistant::ConvertTools
  CONVERT_PROPOSAL_TOOLS = %w[propose_convert_item].freeze

  def prepare_convert_item(args)
    item = cancel_target(args['kind'], args['id'])
    args['kind'] == 'meeting' ? convert_to_task(item, args) : convert_to_meeting(item, args)
  end

  private

  def convert_to_meeting(task, args)
    starts = parse_local(args['starts_at'])
    raise ArgumentError, 'Falta la fecha y hora (YYYY-MM-DDTHH:MM).' unless starts

    minutes = args['duration_minutes'].to_i.positive? ? args['duration_minutes'].to_i : task.estimated_minutes || 60
    payload = { 'kind' => 'task', 'id' => task.id, 'starts_at' => starts.iso8601, 'ends_at' => (starts + minutes.minutes).iso8601,
                'location' => args['location'].to_s }
    keep = !Cases::Conversion.task_replaceable?(task)
    [payload, { 'rows' => [['ITEM', task.title]], 'to_meeting' => true, 'keeps_task' => keep }]
  end

  def convert_to_task(meeting, args)
    raise ArgumentError, 'Esa tarea agendada ya no está pendiente o ya salieron a la visita.' unless Cases::Conversion.meeting_convertible?(meeting)

    has_client = meeting.client_contact.present?
    payload = { 'kind' => 'meeting', 'id' => meeting.id, 'notify_client' => has_client && args['notify'] != false }
    [payload, { 'rows' => [['ITEM', meeting.title]], 'to_meeting' => false, 'has_client' => has_client,
                'linked_task' => meeting.case_task&.title }]
  end
end
