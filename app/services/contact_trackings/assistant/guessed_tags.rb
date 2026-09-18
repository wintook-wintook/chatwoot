# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — ETIQUETAS QUE NADIE ELIGIÓ, EN UN BORRADOR
# ================================================================================
# Mientras la entrevista sigue, el borrador se muestra al lado del chat (fase C). El
# contrato le pide al modelo no escribir #etiqueta hasta que la persona la elija, y
# no lo cumple: medido en 3 de 3 entrevistas reales (15/09/2026), puso #soporte,
# #precio, #asesor antes de preguntar. Un borrador así se lee como decisiones
# tomadas.
#
# Como la instrucción no alcanza, se controla con código: en un BORRADOR, la etiqueta
# de una rama se queda solo si la persona la escribió: con "#" en cualquier mensaje
# (elegirla con un botón manda "1) #demo"), o sin "#" en un mensaje que habla de
# etiquetas ("etiquetas: demo para soporte"). La palabra suelta NO alcanza: medido,
# "#soporte" y "#asesor" sobrevivían porque la persona había escrito "soporte" y
# "pasame con un asesor" como temas, no como etiquetas. La etiqueta es opcional en
# la gramática, así que quitarla deja la línea válida.
#
# En la entrega final no se toca: ahí las etiquetas ya se preguntaron, y si alguna no
# existe lo avisa el comprobador.
# ================================================================================

module ContactTrackings::Assistant::GuessedTags
  module_function

  # [borrador sin las etiquetas adivinadas, etiquetas quitadas]
  TAG_TALK_RE = /etiquet|\blabels?\b|\btags?\b/i

  def strip(draft, said:)
    dicho = Array(said)
    quitadas = []

    texto = draft.to_s.gsub(/^([ \t]*@ruta\([ \t]*[a-z0-9_-]+)[ \t]+#([a-z0-9_]+)/i) do
      prefijo = Regexp.last_match(1)
      etiqueta = Regexp.last_match(2)
      next Regexp.last_match(0) if mentioned?(dicho, etiqueta)

      quitadas << "##{etiqueta}"
      prefijo
    end

    [texto, quitadas.uniq]
  end

  def mentioned?(mensajes, etiqueta)
    nombre = Regexp.escape(etiqueta)
    con_numeral = /(?<![\p{L}\p{N}_])##{nombre}(?![\p{L}\p{N}_])/i
    suelta = /(?<![\p{L}\p{N}_#])#{nombre}(?![\p{L}\p{N}_])/i

    mensajes.any? { |m| m.match?(con_numeral) || (m.match?(TAG_TALK_RE) && m.match?(suelta)) }
  end
end
