# frozen_string_literal: true

# ================================================================================
# feat/tono_editable_asistente — REESCRIBIR [ESTILO] SIN PISAR LO ESCRITO A MANO
# ================================================================================
# Ver ContactTrackings::Ficha::Style (qué es cada frase y cómo se lee). Aquí se cambia SOLO
# lo que se pidió: el tono por su frase, «tú»↔«usted», y cada ajuste por su contrario,
# conservando lo que la persona agregó («…de máximo 4 líneas, salvo la lista del catálogo»
# → «…máximo 2 líneas, salvo la lista del catálogo»). Sin [ESTILO], lo crea completo.
# ================================================================================

module ContactTrackings::Ficha::StyleEditor
  Style = ContactTrackings::Ficha::Style

  module_function

  # Lo que pide la pantalla (todo, cambie o no) → el prompt con SOLO lo que cambió escrito.
  def update(prompt, trato: nil, tone: nil, tone_adjust: {})
    actual = Style.read(prompt)
    cambios = { trato: changed(trato.to_s.presence_in(Style::TRATOS), actual[:trato]),
                tone: changed(tone.to_s.presence_in(Style::TONE_PHRASES.keys), actual[:tone]),
                tone_adjust: adjust_changes(tone_adjust, actual[:tone_adjust]) }
    return prompt if cambios.values.all?(&:blank?)

    write(prompt, **cambios)
  end

  def changed(pedido, actual) = (pedido unless pedido == actual)

  def adjust_changes(pedido, actual)
    pedido = pedido.to_h.stringify_keys
    Style::ADJUSTS.each_with_object({}) do |clave, acc|
      next unless pedido.key?(clave)

      valor = ActiveModel::Type::Boolean.new.cast(pedido[clave]) || false
      acc[clave] = valor unless actual && actual[clave] == valor
    end
  end

  # El prompt con [ESTILO] cambiado. cambios: trato:, tone:, tone_adjust: { 'short' => true, … }
  # (solo las llaves que cambian; las demás se quedan como estén).
  def write(prompt, trato: nil, tone: nil, tone_adjust: {})
    lineas = prompt.to_s.split("\n", -1)
    rango = Style.section_range(lineas)
    return append_section(prompt, trato, tone, tone_adjust) if rango.nil?

    cuerpo = lineas[(rango[0] + 1)...rango[1]].join("\n")
    nuevo = apply_adjusts(apply_tone(cuerpo, trato, tone), tone_adjust.to_h)
    lineas[(rango[0] + 1)...rango[1]] = nuevo.split("\n", -1)
    lineas.join("\n")
  end

  # Tono nuevo: su frase completa en lugar de la conocida (o de la primera «Hablo de …»
  # propia, que el tono reemplaza). Solo trato: cambia «tú»↔«usted» y nada más.
  def apply_tone(cuerpo, trato, tone)
    if tone.present?
      frase = Style.tone_sentence(trato || Style.read_trato(cuerpo), tone)
      return cuerpo.sub(Style::TONE_SENTENCE_RE, frase) if cuerpo.match?(Style::TONE_SENTENCE_RE)
      return cuerpo.sub(/Hablo de (?:tú|tu|usted)\b[^.]*\./i, frase) if cuerpo.match?(Style::TRATO_RE)

      return prepend(cuerpo, frase)
    end
    return cuerpo if trato.blank?
    return cuerpo.sub(Style::TRATO_RE, "Hablo de #{Style.trato_word(trato)}") if cuerpo.match?(Style::TRATO_RE)

    prepend(cuerpo, "Hablo de #{Style.trato_word(trato)}.")
  end

  def apply_adjusts(cuerpo, ajustes)
    cuerpo = toggle(cuerpo, ajustes['short'], Style::SHORT, Style::NORMAL) if ajustes.key?('short')
    cuerpo = toggle(cuerpo, ajustes['emojis'], Style::EMOJIS, Style::NO_EMOJIS) if ajustes.key?('emojis')
    cuerpo = question(cuerpo, ajustes['question']) if ajustes.key?('question')
    cuerpo
  end

  # Cambia una frase por su contraria (conservando lo que la persona le agregó después) o la
  # agrega al final si no había ninguna de las dos.
  def toggle(cuerpo, prendido, con, sin)
    quiere, quita = prendido ? [con, sin] : [sin, con]
    return cuerpo if cuerpo.include?(quiere)
    return cuerpo.sub(quita, quiere) if cuerpo.include?(quita)

    append(cuerpo, quiere.end_with?('.') ? quiere : "#{quiere}.")
  end

  def question(cuerpo, prendido)
    return (cuerpo.include?(Style::QUESTION) ? cuerpo : append(cuerpo, Style::QUESTION)) if prendido

    cuerpo.sub(/[ \t]*#{Regexp.escape(Style::QUESTION)}/o, '')
  end

  def prepend(cuerpo, frase)
    sangria = cuerpo[/\A\n*/]
    "#{sangria}#{frase} #{cuerpo.delete_prefix(sangria)}".sub(/ +\n/, "\n")
  end

  # Al final del último renglón con texto de la sección.
  def append(cuerpo, frase)
    final = cuerpo[/\s*\z/]
    "#{cuerpo.rstrip} #{frase}#{final}"
  end

  def append_section(prompt, trato, tone, tone_adjust)
    base = ContactTrackings::Ficha::Generator::TONE_DEFAULTS.fetch(tone.to_s, {})
    ajustes = Style::ADJUSTS.index_with { |k| tone_adjust.to_h.key?(k) ? tone_adjust[k] : base[k] }
    "#{prompt.to_s.rstrip}\n\n[ESTILO]\n#{Style.body(trato, tone.presence || 'cercano', ajustes)}"
  end
end
