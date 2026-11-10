# frozen_string_literal: true

# Asistente (Dali) — funciones de las guías de uso (formato de OpenAI). Lo que hacen
# vive en Assistant::GuideTools.
module Assistant::GuideToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('search_guides', 'Busca en las guías de uso de la plataforma (cómo se hace algo, dónde está, para qué sirve). ' \
                          'Úsala ANTES de explicar cualquier cosa de cómo funciona la plataforma.',
         { query: D.str('Lo que el usuario quiere saber, en sus palabras') }, %w[query]),
    D.fn('read_guide', 'Lee una guía completa (de search_guides) para contestar con sus pasos.',
         { key: D.str('Clave de la guía, p. ej. casos') }, %w[key]),
    D.fn('report_gap', 'Anota una pregunta de uso que las guías no contestan, para que la documenten. Llámala cuando ' \
                       'leíste la guía y no traía la respuesta.',
         { question: D.str('La pregunta del usuario'), guide_key: D.str('La guía que leíste, si alguna') }, %w[question])
  ].freeze
end
