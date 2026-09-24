# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LAS ETIQUETAS COMO ESTADOS
# ================================================================================
# Del manual de estructura de Kontrolya (24/09/2026): una ruta puede cerrar con
# varias etiquetas según cómo quedó el turno (#cotizar1 = falta aclarar qué quiere
# cotizar; #cotizar2 = ya se entiende y se canaliza). El motor ya lo permite: la
# etiqueta que pone el modelo se respeta y la de la ruta solo se agrega si falta
# (KnowledgeBaseResponseService#with_branch_tag).
#
# La sección [ETIQUETAS] es entonces un DICCIONARIO: una línea por etiqueta, con lo
# que significa. Lo que rompe es la etiqueta SUELTA, sin significado: el agente la
# pega a todas sus respuestas (la conversación 173: «[ETIQUETAS]\n#humano» y cada
# mensaje del bot terminaba en #humano).
#
# Una etiqueta sola en su línea al final de una sección con texto («[SI PIDE HABLAR
# CON UNA PERSONA] … canaliza.\n#humano») SÍ tiene significado: el de la sección
# (así escribe el Coordinador v6.11). Suelta es la de una sección que no tiene nada
# más que etiquetas.
#
#   declared   las etiquetas con significado en la prosa: las que el agente puede
#              poner a propósito. La revisión de conversaciones no las marca como
#              «etiqueta que no es la de su ruta» (ReplySignals).
#   check      hallazgos: etiqueta suelta (ámbar) y etiqueta de estado que no existe
#              en la cuenta (ámbar: no dispara ninguna automatización).
# ================================================================================

module ContactTrackings::Assistant::TagDictionary
  # Como ANY_TAG_RE del motor (mínimo 3), con al menos una letra: «#1» o «#123» no
  # son etiquetas, y «# ROL» (con espacio) es un encabezado Markdown.
  TAG_RE = /(?<![\w&#])#([a-z0-9_]*[a-z][a-z0-9_]*)/i
  MIN_LENGTH = 3

  module_function

  # [[número de línea, línea]] de la prosa: sin las líneas de configuración (@ruta,
  # @ruta_por_defecto), que son del motor.
  def prose_lines(text)
    text.to_s.split("\n", -1).each_with_index.filter_map do |linea, indice|
      next if linea.lstrip.start_with?('@ruta')

      [indice + 1, linea]
    end
  end

  def tags_in(linea)
    linea.scan(TAG_RE).flatten.select { |tag| tag.size >= MIN_LENGTH }.map { |tag| "##{tag.downcase}" }.uniq
  end

  # Una línea con etiquetas y nada más que diga algo.
  def only_tags?(linea)
    tags_in(linea).any? && linea.gsub(TAG_RE, '').gsub(/[^\p{L}]/, '').empty?
  end

  def header?(linea)
    linea.match?(ContactTrackings::Assistant::DraftPieces::SECTION_RE) ||
      linea.match?(ContactTrackings::Assistant::DraftPieces::MARKDOWN_RE) ||
      ContactTrackings::Assistant::StructureChecks.broken_header?(linea)
  end

  # La prosa partida por rótulo: [[[número, línea], …], …] sin el rótulo.
  def sections(text)
    prose_lines(text).slice_before { |_, linea| header?(linea) }
                     .map { |grupo| grupo.reject { |_, linea| header?(linea) } }
  end

  # Las líneas de etiquetas sueltas: las de una sección sin otro texto.
  def bare_lines(text)
    sections(text).flat_map do |grupo|
      con_texto = grupo.any? { |_, linea| linea.match?(/\p{L}/) && !only_tags?(linea) }
      con_texto ? [] : grupo.select { |_, linea| only_tags?(linea) }
    end
  end

  def declared(text)
    sueltas = bare_lines(text).map(&:first)
    prose_lines(text).filter_map { |numero, linea| tags_in(linea) unless sueltas.include?(numero) }.flatten.uniq
  end

  def check(text, map:, account:, findings:)
    bare_lines(text).each do |numero, linea|
      findings.add(:degrading, :bare_tag_line, t('bare_tag_line', line: numero, tags: tags_in(linea).join(' ')),
                   line: numero, wrote: linea.strip)
    end
    missing_state_tags(text, map, account, findings)
  end

  # Las de las rutas ya las revisa check_tags_exist (label_not_found).
  def missing_state_tags(text, map, account, findings)
    existentes = account.labels.pluck(:title).map { |titulo| "##{titulo.downcase}" }
    de_rutas = map.routes.filter_map(&:hashtag).map(&:downcase)
    (declared(text) - de_rutas - existentes).each do |tag|
      findings.add(:degrading, :state_label_not_found, t('state_label_not_found', tag: tag),
                   line: first_line_with(text, tag), wrote: tag)
    end
  end

  def first_line_with(text, tag)
    prose_lines(text).find { |_, linea| tags_in(linea).include?(tag) }&.first
  end

  def t(key, **args)
    I18n.t("tracking_assistant.findings.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end
