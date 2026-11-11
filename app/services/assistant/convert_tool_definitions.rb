# frozen_string_literal: true

# Asistente (Dali) — tarea ↔ tarea agendada (formato de OpenAI). Lo que hace vive en
# Assistant::ConvertTools.
module Assistant::ConvertToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('propose_convert_item', 'Propone pasar una tarea sin hora a la agenda (kind task, con día y hora) o sacar de la agenda ' \
                                 'una tarea agendada y dejarla como tarea sin hora (kind meeting). Requiere confirmación.',
         { kind: { type: 'string', enum: %w[task meeting], description: 'task = tarea a la agenda; meeting = tarea agendada a tarea' },
           id: D.int('Id de la tarea o tarea agendada (de my_agenda o get_case)'),
           starts_at: D.str('kind task: día y hora local, YYYY-MM-DDTHH:MM'),
           duration_minutes: D.int('kind task: duración; si no la dice, lo estimado de la tarea'),
           location: D.str('kind task: lugar, si lo dijo'),
           notify: { type: 'boolean', description: 'kind meeting: avisarle al cliente que se quita la cita (true salvo que diga que no)' } },
         %w[kind id])
  ].freeze
end
