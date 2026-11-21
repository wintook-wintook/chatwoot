# frozen_string_literal: true

# ================================================================================
# Un mensaje de la plática, en corto, para el clasificador de ramas (21/11/2026, Seminuevos Valera)
# ================================================================================
# El clasificador ve los últimos mensajes recortados a 120 caracteres DESDE EL INICIO, y la
# pregunta con la que cierra el agente siempre va al final: veía «Tenemos un Jetta 2019 con
# transmisión automática en color gris plata. El precio de con…» y no «¿Te gustaría verlo
# físicamente?». Las rutas del tipo «ya le pregunté X y contesta que sí» fallaban justo
# cuando la respuesta del agente era larga: el «Sí» se iba a la rama anterior.
#
# Ahora, si el mensaje no cabe, se guarda el inicio y su última pregunta. Las etiquetas
# (#inventario), la fuente (_INVENTARIO_) y la firma (-TB) no cuentan: son el pie del mensaje.
# ================================================================================
module ContactTrackings::ContextLine
  LIMIT = 120
  QUESTION_MAX = 100
  QUESTION_RE = /¿[^¿?]*\?/
  FOOTER_RE = /^[ \t]*(?:(?:#[[:alnum:]_]+[ \t]*)+|_[^_\n]+_|-TB)[ \t]*$/

  module_function

  def brief(text, limit = LIMIT)
    plano = text.to_s.gsub(FOOTER_RE, '').squish
    return plano if plano.size <= limit

    pregunta = plano.scan(QUESTION_RE).last&.truncate(QUESTION_MAX)
    inicio = plano.truncate(limit)
    return inicio if pregunta.nil? || inicio.include?(pregunta)

    "#{plano.truncate([limit - pregunta.size, 40].max)} #{pregunta}"
  end
end
