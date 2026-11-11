# frozen_string_literal: true

# Asistente (Dali) — reportar avance de una tarea (formato de OpenAI). Lo que hace vive en
# Assistant::ProgressTools.
module Assistant::ProgressToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('task_history', 'Historial de una tarea: estado, vencimiento, tiempo reportado contra lo estimado y lo que pasó ' \
                         '(notas, reportes de avance y de cierre, sus tareas agendadas, lo del cliente y cambios).',
         { id: D.int('Id de la tarea (de my_agenda o get_case)') }, %w[id]),
    D.fn('propose_task_progress', 'Propone reportar AVANCE de una tarea pendiente: lo que se hizo sin completarla. Es un ' \
                                  'reporte (sale en «Ver reportes» de la tarea y en la actividad del caso), no una nota. ' \
                                  'Requiere confirmación.',
         { id: D.int('Id de la tarea (de my_agenda o get_case)'),
           notes: D.str('Lo que se hizo, ordenado y claro, con las palabras del usuario'),
           minutes: D.int('Minutos dedicados, si los dijo') },
         %w[id notes])
  ].freeze
end
