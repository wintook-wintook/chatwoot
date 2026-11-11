# frozen_string_literal: true

# Asistente (Dali) — reportar avance de una tarea (formato de OpenAI). Lo que hace vive en
# Assistant::ProgressTools.
module Assistant::ProgressToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('propose_task_progress', 'Propone reportar AVANCE de una tarea pendiente: lo que se hizo sin completarla. Es un ' \
                                  'reporte (sale en «Ver reportes» de la tarea y en la actividad del caso), no una nota. ' \
                                  'Requiere confirmación.',
         { id: D.int('Id de la tarea (de my_agenda o get_case)'),
           notes: D.str('Lo que se hizo, ordenado y claro, con las palabras del usuario'),
           minutes: D.int('Minutos dedicados, si los dijo') },
         %w[id notes])
  ].freeze
end
