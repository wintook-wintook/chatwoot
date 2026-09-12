# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LEER LA RESPUESTA DEL MODELO
# ================================================================================
# El JSON que devuelve el asistente trae, además del mensaje y el Entrenamiento,
# dos cosas que la pantalla consume directo: la PROPUESTA (nombre, objetivo,
# contexto del agente) y las OPCIONES (las preguntas del turno, en forma de
# botones).
#
# Se leen acá, aparte de la entrevista, porque son lo único del payload que se
# lee CON DESCONFIANZA: lo escribe un modelo, así que se recorta en cantidad y en
# largo antes de que llegue a una pantalla. El resto del JSON lo verifica el
# comprobador; esto no tiene quién lo verifique, y por eso tiene topes propios.
# ================================================================================

class ContactTrackings::Assistant::ReplyParser
  # ⚠ El tope de preguntas estaba en 6 y el modelo hizo 7: la séptima —la
  # obligatoria, "¿contesta o deriva?"— se cayó SIN AVISO y quedó escrita en el
  # mensaje pero sin botones. Ahora el tope va por encima de lo que el contrato
  # permite pedir (4 por turno), así que el recorte es una red de seguridad y no
  # algo que se dispare en el uso normal.
  MAX_QUESTIONS = 10
  MAX_CHOICES = 8
  MAX_CHOICE_CHARS = 60
  MAX_QUESTION_CHARS = 160

  class << self
    # Los datos del agente que el asistente propone junto al Entrenamiento. Se
    # rescatan con cuidado: `contexto` es el único que puede hacer daño si el
    # modelo lo rellena de memoria —entra al prompt como "BASE DE CONOCIMIENTO" y
    # el agente lo cita como si fuera cierto—, así que se toma tal cual vino y la
    # pantalla lo muestra editable, nunca oculto.
    def proposal(reply)
      raw = reply['propuesta']
      return nil unless raw.is_a?(Hash)

      { name: raw['nombre'].to_s.strip, objective: raw['objetivo'].to_s.strip,
        ai_context: raw['contexto'].to_s.strip }
    end

    # Las preguntas que el asistente acaba de hacer, en forma de lista, para que
    # la pantalla las muestre como botones. Se descarta cualquier pregunta sin
    # elecciones: un botón vacío no sirve para nada.
    def options(reply)
      raw = reply['opciones']
      return nil unless raw.is_a?(Array)

      limpias = raw.first(MAX_QUESTIONS).filter_map { |item| question_from(item) }
      limpias.presence
    end

    private

    def question_from(item)
      return unless item.is_a?(Hash)

      elecciones = Array(item['elecciones']).first(MAX_CHOICES)
                                            .map { |c| c.to_s.strip.truncate(MAX_CHOICE_CHARS) }
                                            .compact_blank
      return if elecciones.empty?

      { question: item['pregunta'].to_s.strip.truncate(MAX_QUESTION_CHARS), choices: elecciones }
    end
  end
end
