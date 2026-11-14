# frozen_string_literal: true

# Asistente (Dali) — preguntas de cómo se usa la plataforma («¿cómo creo un contrato?»,
# «¿para qué sirve el embudo?»). Las respuestas salen de las guías del repo
# (Assistant::Guides), nunca de lo que el modelo crea saber.
#
#   search_guides(query) → las guías que coinciden; si no hay, anota la pregunta
#   read_guide(key)      → el texto de una guía (solo si el usuario tiene su área)
#   report_gap(question) → la guía no traía la respuesta: se anota para escribirla
#
# Lo anotado (AssistantGuideGap) lo revisa el equipo de Kontrolya en el Super Admin.
# Una sola anotación por turno aunque el modelo llame más de una función.
# Se incluye en Assistant::Tools.
module Assistant::GuideTools
  GUIDE_TOOLS = %w[search_guides read_guide report_gap].freeze

  # Lo que el usuario escribió en este turno y dónde estaba (lo pone Assistant::Chat).
  attr_accessor :turn

  # Las guías que se encontraron o leyeron en este turno: Assistant::Chat las guarda en la
  # respuesta para que un «sí» o «ábrela» del siguiente turno sepa cuál era (sin la clave,
  # el modelo pedía read_guide con el título y fallaba).
  def guides_now = @guides_now.to_a.uniq

  def tool_search_guides(args)
    results = Assistant::Guides.search(args['query'], @grant)
    (@guides_now ||= []).concat(results.pluck(:key))
    return { guides: results } if results.any?

    record_gap('no_guide')
    { guides: [], note: 'No hay guía de eso. Dilo así («eso todavía no lo tengo documentado; ya quedó anotado») y no inventes ' \
                        'pantallas ni pasos.' }
  end

  def tool_read_guide(args)
    guide = Assistant::Guides.find(args['key'], @grant)
    return missing_guide(args['key']) unless guide

    @last_guide_key = guide.key
    (@guides_now ||= []) << guide.key
    { key: guide.key, title: guide.title, content: guide.body,
      pages: guide.pages.index_with { |key| Assistant::Pages.label(key) },
      url: Assistant::GuidePublisher.article_url(guide.key) }.compact
  end

  def tool_report_gap(args)
    record_gap('not_covered', question: args['question'], guide_key: args['guide_key'].presence || @last_guide_key)
    { ok: true, note: 'Quedó anotado para documentarlo.' }
  end

  private

  # Sin anotar nada todavía: le damos las que se parecen para que lea la buena.
  def missing_guide(key)
    similar = Assistant::Guides.search(key, @grant)
    { error: 'Esa guía no existe o el usuario no tiene acceso a esa área. Usa la `key` (no el título).',
      guides: similar }.compact_blank
  end

  def record_gap(reason, question: nil, guide_key: nil)
    return if @gap_recorded

    @gap_recorded = true
    AssistantGuideGap.record!(account: @account, user: @user, reason: reason, guide_key: guide_key,
                              question: turn.to_h[:question].presence || question, page: turn.to_h[:page])
  end
end
