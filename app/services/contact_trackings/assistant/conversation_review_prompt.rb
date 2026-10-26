# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL PEDIDO A gpt-4o PARA REVISAR UNA CONVERSACIÓN
# ================================================================================
# Aparte de ConversationReview, que arma la evidencia y junta el resultado: el texto
# del pedido es largo y se afina a prueba (medido con la 173, 24/09/2026).
# ================================================================================

class ContactTrackings::Assistant::ConversationReviewPrompt
  # La conversación, un mensaje por renglón: #n · quién · cuándo · texto, y debajo lo
  # que el motor hace hoy con cada mensaje del cliente y las señales de cada respuesta.
  def self.transcript(turns, engine, signals)
    turns.map do |t|
      linea = "##{t.n} · #{t.role} · #{t.at.strftime('%d/%m %H:%M')} · #{t.content}"
      linea += "\n      motor hoy: #{engine_line(engine[t.n])}" if engine[t.n]
      senales = Array(signals[t.n]).map { |s| ContactTrackings::Assistant::ReplySignals.describe(s) }
      senales.any? ? "#{linea}\n      señales (ya reportadas): #{senales.join(' · ')}" : linea
    end.join("\n")
  end

  # Una línea por mensaje: es para el modelo, no para la pantalla.
  def self.engine_line(payload)
    return 'no se pudo probar' if payload.nil?

    fuente = payload[:source] || {}
    partes = ["ruta: #{payload.dig(:routes, :chosen) || 'ninguna'}"]
    partes << "fuente: #{fuente[:directive] || 'ninguna'} (#{source_state(fuente)})"
    partes << "etiqueta: #{payload[:tag]}" if payload[:tag].present?
    partes << 'abriría un caso' if payload.dig(:case, :creates)
    partes.join(' · ')
  end

  def self.source_state(fuente)
    return "#{Array(fuente[:items]).size} fragmentos" if fuente[:items]

    fuente[:reason].to_s.presence || 'sin fuente'
  end

  # ran: el Entrenamiento que corrió; current: el actual del agente si cambió después.
  def initialize(ran:, current:, facts:, note:, transcript:)
    @ran = ran.to_s
    @current = current
    @facts = facts
    @note = note
    @transcript = transcript
  end

  def call
    <<~PROMPT
      Revisas una conversación REAL entre un cliente y un agente de IA de atención, para decirle a quien administra el
      agente qué respuestas estuvieron mal, por qué y qué cambiar. Escribe en #{ContactTrackings::Assistant::Language.name_for},
      de tú, en lenguaje llano.

      EL ENTRENAMIENTO CON EL QUE CONTESTÓ EL AGENTE:
      <<<ENTRENAMIENTO
      #{@ran.presence || '(no tiene: ningún Agente IA atendió esta conversación)'}
      ENTRENAMIENTO>>>
      #{current_block}
      HECHOS DE CONFIGURACIÓN (comprobados, no opiniones):
      #{facts_text}

      LA CONVERSACIÓN (#n · quién · texto; los datos personales van tapados):
      #{@transcript}

      Debajo de cada mensaje del cliente, «motor hoy» es lo que el motor real hace HOY con ese mensaje (ruta, fuente,
      etiqueta). Es evidencia de cómo rutea; no es un registro de lo que pasó ese día.
      #{note_block}
      REGLAS DEL MOTOR QUE DEBES TENER PRESENTES:
      - Cada @ruta agrega su #etiqueta sola a sus respuestas; una etiqueta que sale en TODAS es una sección general
        de etiquetas, y es un error de entrenamiento.
      - @agendar_calendar solo ofrece horarios si el agente tiene un calendario asignado (configuración, no entrenamiento).
      - Prometer algo que el agente no puede hacer («te confirmo en un momento») es un error.

      Juzga TODAS las respuestas del bot (las marcadas «bot»), una por una, contra lo que pidió el cliente justo antes
      y contra el Entrenamiento. Está MAL si: no hace lo que el Entrenamiento dice que hace (p. ej. dice «no tengo
      acceso» a algo que su ruta sí consulta), promete algo que no hace, ignora lo que pidió el cliente o inventa datos.
      Las «señales» ya se le reportan a la persona aparte: no las repitas; juzga todo lo demás de esa respuesta (si solo
      tiene la señal, es "bien"). Para cada respuesta del bot:
        n                el número del mensaje del bot
        veredicto        "bien" | "mal" | "dudoso"
        que_paso         qué contestó y qué tiene de malo, en una o dos frases
        que_se_esperaba  qué debió contestar o hacer
        causa            "entrenamiento" (falta o sobra una regla, una ruta, una fuente) | "configuracion" (calendario,
                         fuente sin conectar, copia vieja del Entrenamiento) | "motor" (el Entrenamiento y la
                         configuración están bien y aun así falló) | "cliente" (el cliente fue ambiguo; no es falla)
        arreglo          qué cambiar, concreto: la regla a agregar o quitar en el Entrenamiento, o qué configurar y dónde
        ya_corregido     true si el Entrenamiento ACTUAL del agente ya lo corrige (solo si se te dio)
      Con "bien" basta n y veredicto. No inventes fallas, pero tampoco des por buena una respuesta que no resolvió lo
      que el cliente pidió. Si la persona señaló algo, atiéndelo y di en qué respuesta pasó.

      Responde SOLO un JSON:
      {"resumen": "2 a 3 frases con lo más importante",
       "turnos": [{"n": 2, "veredicto": "bien"}, {"n": 4, "veredicto": "mal", "que_paso": "...", "que_se_esperaba": "...", "causa": "...", "arreglo": "...", "ya_corregido": false}],
       "cambios_entrenamiento": ["solo los de causa entrenamiento (nada de configuración), cada uno en una frase, listo para pedírselo al editor"]}
    PROMPT
  end

  private

  # Si el Agente IA cambió después, se le da la versión actual para que marque lo que
  # ya está corregido: no se le pide a la persona arreglar algo que ya arregló.
  def current_block
    actual = @current
    return '' if actual.blank?

    <<~TXT

      EL ENTRENAMIENTO ACTUAL DEL AGENTE (cambió después; esta conversación sigue con el de arriba):
      <<<ACTUAL
      #{actual}
      ACTUAL>>>
    TXT
  end

  FACT_TEXT = {
    'no_agent' => 'Ningún Agente IA atendió esta conversación.',
    'no_calendar' => 'El Entrenamiento agenda (@agendar_calendar) y el agente NO tiene calendario asignado: no puede ofrecer horarios.',
    'calendar_ok' => 'El agente tiene calendario asignado HOY. No se sabe desde cuándo: si la conversación falló por no ' \
                     'tener horarios, la causa es configuración y ya está corregida.',
    'stale_copy' => 'La conversación usa una copia VIEJA del Entrenamiento: lo que se corrigió después en el agente no le llega.'
  }.freeze

  def facts_text
    return '- ninguno' if @facts.empty?

    @facts.map { |f| "- #{FACT_TEXT[f[:code]] || "El comprobador marca como bloqueante: #{f[:message]}"}" }.join("\n")
  end

  def note_block
    return '' if @note.blank?

    "\nLO QUE DICE LA PERSONA QUE LA REVISA (atiéndelo primero):\n#{@note}\n"
  end
end
