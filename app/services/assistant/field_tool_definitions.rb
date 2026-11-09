# frozen_string_literal: true

# Asistente (Dali) — funciones del trabajo en campo (formato de OpenAI). Lo que hacen vive en
# Assistant::FieldTools.
module Assistant::FieldToolDefinitions
  D = Assistant::ToolDefinitions
  KIND = { type: 'string', enum: %w[order visit], description: 'order = orden de trabajo; visit = visita agendada sin orden' }.freeze

  ALL = [
    D.fn('my_route', 'Las visitas del día del usuario (órdenes de trabajo en campo y visitas agendadas), en orden de hora, ' \
                     'con cliente, dirección y estado (pending, on_the_way, working, done).',
         { day: D.str('Día YYYY-MM-DD; vacío = hoy') }),
    D.fn('get_visit', 'Detalle de una visita: qué hay que hacer, la lista (checklist) de la orden, lo ya anotado, lo que ' \
                      'falta para terminar y las últimas visitas a ese cliente.',
         { kind: KIND, id: D.int('id de my_route') }, %w[kind id]),
    D.fn('propose_on_my_way', 'Propone avisarle al cliente «voy en camino» con la hora estimada de llegada.',
         { kind: KIND, id: D.int('id de my_route'), eta_minutes: D.int('Minutos para llegar (30 si no lo dijo)') },
         %w[kind id eta_minutes]),
    D.fn('propose_visit_report', 'Propone el reporte de la visita con lo que el usuario dictó. En una orden: nota en la ' \
                                 'bitácora y los puntos de la lista que dijo que hizo. En una visita agendada: reporte de ' \
                                 'cierre y la visita queda realizada.',
         { kind: KIND, id: D.int('id de my_route'), notes: D.str('Lo que se hizo, ordenado y claro, con las palabras del usuario'),
           done_task_ids: { type: 'array', items: { type: 'integer' }, description: 'Puntos de la lista (get_visit) que dijo que hizo' },
           minutes: D.int('Minutos dedicados, solo en visita agendada y si los dijo') }, %w[kind id notes])
  ].freeze
end
