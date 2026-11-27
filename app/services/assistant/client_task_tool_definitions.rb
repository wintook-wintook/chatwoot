# frozen_string_literal: true

# Asistente (Dali) — funciones de tareas con el cliente (formato de OpenAI). Lo que hacen vive
# en Assistant::ClientTaskTools.
module Assistant::ClientTaskToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('client_tasks', 'Tareas con el cliente: las que le tocan al cliente (y las nuestras que ve) con su avance, ' \
                         'quién la completó y el enlace de su portal. Filtra por caso, organización, contacto o vencidas.',
         { case_id: D.int('Id del caso'), organization_id: D.int('Id de la organización'), contact_id: D.int('Id del contacto'),
           overdue: { type: 'boolean', description: 'Solo las del cliente vencidas' } }),
    D.fn('propose_client_task', 'Propone asignarle una tarea al cliente en un caso (la trabaja en su portal: probar, enviar, ' \
                                'aprobar, estudiar…) y avisarle con el enlace.',
         { case_id: D.int('Id del caso (case_id de client_tasks o de search)'), folio: D.str('O el folio del caso, p. ej. IMA-00002'),
           title: D.str('Qué tiene que hacer el cliente'), description: D.str('Instrucciones'),
           due_at: D.str('Día límite YYYY-MM-DD, si lo dijo (vence al final del día)'),
           requires_file: { type: 'boolean', description: 'Si debe subir un archivo (documento, evidencia)' },
           notify: { type: 'boolean', description: 'Avisarle con el enlace (true salvo que diga que no)' } },
         %w[title])
  ].freeze
end
