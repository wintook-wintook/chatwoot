# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — OFERTAS ESCALONADAS: EL MODELO SOLO VE LA QUE TOCA
# ================================================================================
# Un Entrenamiento negocia por pasos con una variable de «siguiente oferta»:
#
#   [VARIABLES]
#   SIGUIENTE_OFERTA = PRIMERA_BECA | SEGUNDA_BECA | AGOTADA
#
# y la ficha de cada carrera trae todas las ofertas:
#
#   - Primera beca: 38% toda la Licenciatura, paga $1,990.00 …
#   {{tsbeca1mat}}
#   - Segunda beca: 52% los 3 primeros cuatrimestres …
#   {{tsbeca2mat}}
#
# Medido el 13/11/2026 (cuenta 613 conv 87; dev canal 2450 convs 259-264, gpt-4o-mini):
# con SIGUIENTE_OFERTA=PRIMERA_BECA en las variables y el prompt prohibiéndolo con dos
# redacciones, «¿y no hay otra beca más?» dio la SEGUNDA beca 4 de 4 veces y marcó
# AGOTADA: la primera ya no se ofrecía nunca. «Otra… más» le pesa más que la regla.
#
# No se le pide al modelo: el motor quita de la fuente los renglones de las ofertas que
# vienen DESPUÉS del valor actual (con sus renglones de continuación, p. ej. la imagen),
# antes de que el modelo la lea. Lo que ya se entregó sigue a la vista (el cliente puede
# reclamarlo); lo que no toca todavía, no existe para el modelo.
#
# Solo aplica:
#   · a variables cuyo nombre dice «siguiente» (SIGUIENTE_, PROXIMA_/PROXIMO_, NEXT_): el
#     valor actual ES la oferta que toca. Con otra semántica («OFERTA_DADA=NINGUNA|…») el
#     valor actual es la última entregada y ocultar «lo de después» escondería la que toca.
#   · si la fuente trae renglones de al menos 2 valores de la lista («- Primera beca:»
#     para PRIMERA_BECA): así un texto que no es una lista de ofertas no se toca.
# ================================================================================

module KnowledgeBase::StagedOffers
  NAME_RE = /\A(?:SIGUIENTE|PROXIM[AO]|NEXT)_/
  BULLET = /[-*•·]/
  MIN_LABELED = 2

  module_function

  # content sin los renglones de las ofertas que no tocan todavía (o igual, si no aplica).
  # values: { 'SIGUIENTE_OFERTA' => 'PRIMERA_BECA', … } con las claves normalizadas.
  def filter(content, definition, values)
    return content if content.blank? || definition.blank?

    hidden = hidden_labels(content, definition, values)
    return content if hidden.empty?

    strip_lines(content, hidden, placeholder(current_name(content, definition, values)))
  end

  # Cómo se llama en la ficha la oferta que toca ahora («Primera beca»), o nil.
  def current_name(content, definition, values)
    rotulos = definition.variables.filter_map { |clave, _| label(values[clave]) if clave.match?(NAME_RE) }
    content.each_line do |line|
      match = line.match(LINE_LABEL_RE)
      return match[1].strip if match && rotulos.include?(label(match[1]))
    end
    nil
  end

  # Los rótulos («segunda beca») de las ofertas que vienen después del valor actual.
  def hidden_labels(content, definition, values)
    presentes = line_labels(content)
    definition.variables.flat_map do |clave, var|
      clave.match?(NAME_RE) ? after_current(var[:options], values[clave], presentes) : []
    end.uniq
  end

  # Los rótulos presentes de las opciones que vienen después de la actual.
  def after_current(options, actual, presentes)
    rotulos = options.map { |opcion| label(opcion) }
    return [] if rotulos.count { |rotulo| presentes.include?(rotulo) } < MIN_LABELED

    indice = rotulos.index(label(actual))
    return [] if indice.nil?

    rotulos.drop(indice + 1).select { |rotulo| presentes.include?(rotulo) }
  end

  # Una variable de «siguiente oferta» avanza a lo más un paso por respuesta: el modelo dio
  # la primera beca y escribió SIGUIENTE_OFERTA=AGOTADA (se saltó la segunda, dev convs
  # 265-267). Retroceder sí se permite (cambio de carrera → PRIMERA_BECA).
  # changes: { 'SIGUIENTE_OFERTA' => 'AGOTADA' } (nombres declarados); actuales: claves normalizadas.
  def one_step(definition, actuales, changes)
    changes.to_h do |nombre, valor|
      clave = ContactTrackings::ConversationVariables.key(nombre)
      var = definition.variables[clave]
      [nombre, var && clave.match?(NAME_RE) ? limit_step(nombre, var[:options], actuales[clave], valor) : valor]
    end
  end

  def limit_step(nombre, options, antes, despues)
    desde = options.index(antes)
    hasta = options.index(despues)
    return despues if desde.nil? || hasta.nil? || hasta <= desde + 1

    Rails.logger.info "[Variables] 🎚️ #{nombre}: #{antes} → #{despues} salta pasos; se guarda #{options[desde + 1]}"
    options[desde + 1]
  end

  # «PRIMERA_BECA» → «primera beca» (sin acentos, minúsculas).
  def label(value)
    I18n.transliterate(value.to_s).tr('_', ' ').squish.downcase
  end

  # Rótulo de un renglón «- Primera beca: …» (nil si no tiene esa forma).
  LINE_LABEL_RE = /\A[ \t]*(?:#{BULLET}[ \t]*)?([^:\n]{2,40}?)[ \t]*:/

  def line_label(line)
    match = line.match(LINE_LABEL_RE)
    match && label(match[1])
  end

  def line_labels(content)
    content.each_line.filter_map { |line| line_label(line) }.to_set
  end

  # En lugar de la oferta oculta. Sin el aviso, el modelo veía una sola beca y le decía al
  # cliente «no contamos con otra beca», y marcaba AGOTADA (dev convs 265-267, 3 de 3).
  # Con un aviso que solo decía «hay otra oferta que todavía no toca», ante «¿y no hay otra
  # beca más?» sin haber dado el precio el modelo anunció «una segunda beca» sin montos y se
  # saltó la primera (prod 613 conv 88). Por eso el aviso nombra la que SÍ toca.
  PLACEHOLDER = '- (Hay otra oferta que todavía no toca: no la menciones, no la anuncies y no digas que no ' \
                "hay más; se mostrará aquí cuando el cliente vuelva a objetar el precio.)\n"

  def placeholder(actual)
    return PLACEHOLDER if actual.blank?

    '- (La siguiente oferta todavía no toca. Si el cliente pide otra beca, otro descuento u otra oferta, ' \
      "lo que le toca ahora es «#{actual}», la de arriba: dela completa, con su imagen si la tiene. No " \
      "menciones que hay más ni digas que no hay más.)\n"
  end

  # Cambia cada renglón oculto (y los que le siguen hasta el próximo renglón con viñeta, una
  # línea en blanco o el próximo rótulo) por el aviso, una sola vez por bloque.
  def strip_lines(content, hidden, aviso = PLACEHOLDER)
    skipping = false
    content.each_line.with_object(+'') do |line, out|
      if hidden.include?(line_label(line).to_s)
        out << aviso unless out.end_with?(aviso)
        skipping = true
      else
        skipping &&= !starts_new_block?(line)
        out << line unless skipping
      end
    end
  end

  def starts_new_block?(line)
    line.strip.empty? || line.match?(/\A[ \t]*#{BULLET}/o) || line_label(line).present?
  end
end
