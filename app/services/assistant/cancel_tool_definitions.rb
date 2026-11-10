# frozen_string_literal: true

# Asistente (Dali) — cancelar tareas y tareas agendadas (formato de OpenAI). Lo que hace vive en
# Assistant::CancelTools.
module Assistant::CancelToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('propose_cancel_item', 'Propone cancelar una tarea o tarea agendada que ya no se va a hacer (no es completarla ni ' \
                                'borrarla). Si solo cambia la fecha, propón moverla en lugar de cancelarla.',
         { kind: { type: 'string', enum: %w[task meeting], description: 'task = tarea; meeting = tarea agendada' },
           id: D.int('Id de la tarea o tarea agendada (de my_agenda o get_case)'),
           reason: D.str('Motivo: «El cliente ya no lo necesita», «Se resolvió de otra forma», «Duplicada», «Se reprogramó» u «Otro»'),
           comment: D.str('Lo que dijo el usuario del porqué, si lo dijo'),
           minutes: D.int('Minutos dedicados, si los dijo'),
           notify: { type: 'boolean', description: 'En tarea agendada: avisarle al cliente (true salvo que diga que no)' } },
         %w[kind id reason])
  ].freeze
end
