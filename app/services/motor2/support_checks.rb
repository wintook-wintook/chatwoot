# frozen_string_literal: true

# Motor 2.0 — revisiones de «Atención a clientes» › Soporte antes de mandar el mensaje (del prompt del
# Coordinador Kontrolya v5.6; las corre Motor2::QuestionGuard#guard_turn):
#   - no diagnosticar: «puede deberse», «probablemente», «normalmente pasa»… se le pide una vez que lo
#     quite (si la fuente lo dice, que lo diga tal cual) y, si insiste, se quitan esas frases;
#   - no simular: «lo estoy revisando», «te mantendré informado»… (no hay ese seguimiento) igual;
#   - lo que afirma de Soporte se revisa contra lo que trajeron las fuentes (Motor2::EvidenceCheck con
#     support: true), igual que Comercial › información (Motor2::AreaChecks#ensure_evidence);
#   - al final: lo que agregan las habilidades (finish_reply) y las etiquetas de la conversación (labels).
# Lo incluye Motor2::Runner (usa @mode, @decision, @trace, #run, #clean, #unsourced?, #find_skill, #acted_now?).
module Motor2::SupportChecks
  GUESS = /\b(puede\s+deberse|puede\s+ser\s+(porque|por)|podr[ií]a\s+deberse|posiblemente|probablemente|es\s+probable|seguramente|
           (normalmente|generalmente)\s+(ocurre|pasa|sucede|se\s+debe)|esto\s+puede\s+pasar\s+si|suele\s+(pasar|ocurrir|deberse))\b/xi
  SIMULATED = /\b(lo\s+estoy\s+revisando|estoy\s+revisando|estar[eé]\s+(al\s+)?pendiente|te\s+mantendr[eé]\s+informad\w*|
               te\s+aviso\s+en\s+cuanto|d[eé]jame\s+(revisarlo|checarlo|verificarlo))\b/xi
  NO_GUESS = 'Tu respuesta supone causas o promete un seguimiento que no existe («%<frase>s»). Reescríbela sin eso: si tus ' \
             'fuentes dicen la causa o la solución, dila tal cual, sin «probablemente»; si no, no la supongas. No digas que lo ' \
             'estás revisando ni que le vas a avisar.'
  NOT_CONFIRMED_SUPPORT = 'Revisé tu respuesta contra lo que trajeron tus fuentes: %<falta>s no está confirmado. Reescríbela con ' \
                          'SOLO lo que dicen las fuentes, con sus mismos nombres y pasos, sin causas ni diagnósticos supuestos. ' \
                          'Si no hay nada que lo resuelva, dile que no encontraste documentación específica para darle una ' \
                          'respuesta segura.'
  FALLBACK_SUPPORT = 'No encontré documentación específica para darte una respuesta segura sobre este caso. Si quieres, lo paso ' \
                     'con un asesor de soporte para que lo revise.'

  private

  def ensure_no_guessing(messages, text)
    return text unless guessing?(text)

    @trace.event(:revision, "supuso o prometió: #{text[GUESS] || text[SIMULATED]}")
    messages << { role: 'assistant', content: text } << { role: 'system', content: format(NO_GUESS, frase: text[GUESS] || text[SIMULATED]) }
    again = clean(run(messages))
    again = text if again.blank? || unsourced?(again)
    guessing?(again) ? without_guesses(again) : again
  end

  def guessing?(text)
    @mode == :reply && @decision.nil? && find_skill('areas') && (text.match?(GUESS) || text.match?(SIMULATED))
  end

  # Si insiste, se quitan las frases que suponen o prometen (las demás se quedan).
  def without_guesses(text)
    kept = text.split(/(?<=[.!?])\s+/).reject { |s| s.match?(GUESS) || s.match?(SIMULATED) }.join(' ').strip
    kept.presence || FALLBACK_SUPPORT
  end

  # Soporte (o una plática sin área en la que ya buscó): lo que afirma se revisa contra las fuentes.
  def support_evidence?
    areas = find_skill('areas')
    return false unless areas && @mode == :reply && @decision.nil? && !acted_now?

    areas.area_key == 'support' || (areas.area_key == 'none' && searched_now?)
  end

  def searched_now? = @trace.tools.any? { |t| t['name'] == 'buscar_en_fuentes' }

  # Lo que el código agrega al final (las fuentes y RESUELTO / ESCALAR de Soporte: Motor2::Skills::SupportFlow).
  def finish(text)
    return text unless @mode == :reply

    @skills.reduce(text) { |current, skill| skill.respond_to?(:finish_reply) ? skill.finish_reply(current) : current }
  end

  # Las etiquetas de la conversación (cómo lo catalogó la IA); van a la traza para el probador.
  def labels
    list = @skills.flat_map { |skill| skill.respond_to?(:labels) ? skill.labels : [] }.uniq
    @trace.event(:etiquetas, list.join(' ')) if list.any?
    list
  end
end
