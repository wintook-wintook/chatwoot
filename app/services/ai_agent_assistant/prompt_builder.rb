# frozen_string_literal: true

# ================================================================================
# proyecto@ai_agent_assistant - F3
# ================================================================================
# Servicio: AiAgentAssistant::PromptBuilder
# Descripción: Ensambla el system prompt de las DOS rutas del motor. Fuente única.
#
# POR QUÉ EXISTE:
#   El probador tiene que enseñar lo que el modelo recibe DE VERDAD. Si duplicara
#   el ensamblado, derivaría del motor a la primera corrección y el probador
#   mentiría — que es justo el fallo que el módulo entero intenta evitar.
#   Por eso el job y el analyzer llaman aquí, y el probador también.
#
# LAS DOS RUTAS
#   scheduled     ContactTrackingJob · mensaje programado de cada intento.
#                 Tope real: 150 tokens y «Máximo 2 oraciones».
#   conversational ContactTrackingResponseAnalyzerJob · respuesta al cliente.
#                 Tope real: 250 tokens y «Máximo 4 líneas».
#                 Aquí es donde `clean_cp` puede vaciar el prompt entero (T2).
#
# Los valores que dependen de la conversación viva (estado de la cita, próximo
# contacto, historial) entran por parámetro: el motor pasa los reales y el
# probador pasa los simulados, pero el TEXTO que los envuelve es el mismo.
# ================================================================================

class AiAgentAssistant::PromptBuilder
  # Las cuatro que hacen clean_cp = ''. Espejo de has_kbase_directive en el analyzer;
  # el spec de Capabilities garantiza que el catálogo no se desincronice de esta lista.
  KBASE_DIRECTIVES = /@buscar_predefinidas\b|@buscar_art[ií]culo\b|@buscar_foro\([^)]*\)|@discourse\b/i

  class << self
    # ---------------------------------------------------------------- RUTA A
    def scheduled_system(tracking, contact_profile: nil, contact_name: nil)
      name = contact_name.presence || tracking.contact&.name.presence || 'Hola'
      profile = contact_profile.presence ? "\n\nPERFIL DEL CONTACTO:\n#{contact_profile}" : ''
      extra = tracking.complementary_prompt.present? ? "\n\nINSTRUCCIONES ADICIONALES DEL AGENTE:\n#{tracking.complementary_prompt}" : ''

      <<~SYSTEM.strip
        Eres un asistente de seguimiento al cliente para #{tracking.account.name}.

        INFORMACIÓN DEL CLIENTE:
        - Nombre: #{name}#{profile}

        CONTEXTO INTERNO (no mencionar al cliente):
        - Objetivo: #{tracking.objective}
        - Contexto: #{tracking.ai_context}
        - Este es el intento número #{tracking.attempt_count + 1} de #{tracking.max_attempts}#{extra}

        REGLAS GENERALES:
        - Nunca menciones "intentos", "seguimiento automático" ni detalles técnicos
        - Mantén un tono cordial y profesional, como si lo escribiera un agente humano
        - Máximo 2 oraciones
        - En español
        - NO incluyas comillas al inicio ni al final del mensaje
      SYSTEM
    end

    def scheduled_task(tracking, template_content: nil)
      return generic_task if template_content.blank?

      <<~TASK.strip
        PLANTILLA BASE (intento #{tracking.attempt_count + 1}):
        "#{template_content}"

        Usa la plantilla como estructura principal y PERSONALÍZALA con los datos del contexto.
        REGLAS: Mantén estructura y propósito. Reemplaza placeholders con info real del contexto.
        NO expandas con información adicional. NO agregues precios ni condiciones fuera de la plantilla.
        Genera solo el mensaje final, sin comillas, sin explicaciones.
      TASK
    end

    # ---------------------------------------------------------------- RUTA B
    # `clean_cp` es la pieza cara: con una directiva de búsqueda queda vacío y el
    # prompt del agente no llega al modelo.
    def clean_complementary_prompt(raw)
      text = raw.to_s
      return '' if text.match?(KBASE_DIRECTIVES)

      text.gsub(/@agendar_calendar\b/i, '').strip
    end

    def conversational_system(tracking, appointment_state:, next_contact:, contact_profile: '',
                              attachment_directive: false)
      clean_cp = clean_complementary_prompt(tracking.complementary_prompt)

      <<~SYSTEM.strip
        Eres un asesor de ventas para #{tracking.account.name}.
        Responde como un humano amable y conocedor del tema. NUNCA menciones que eres un bot o sistema automático.

        #{contact_profile}
        OBJETIVO DE LA CONVERSACIÓN: #{tracking.objective}
        ESTADO DE LA CITA: #{appointment_state} (si el cliente pregunta por su cita, respóndele con esta fecha/hora exacta; no inventes ni ofrezcas horarios nuevos)
        PRÓXIMO CONTACTO PROGRAMADO: #{next_contact} (si el cliente pide reagendar, infórmale amablemente que su próximo contacto ya está programado para esa fecha y que si necesita cambiarlo debe comunicarse con un asesor)
        #{tracking.ai_context.present? ? "BASE DE CONOCIMIENTO:\n#{tracking.ai_context.truncate(800)}\n" : ''}
        #{clean_cp.present? ? "INSTRUCCIONES ADICIONALES:\n#{clean_cp}" : ''}
        #{attachment_directive ? attachment_instructions : ''}
      SYSTEM
    end

    def conversational_user(first_name, message_text, message_history: '')
      <<~USER.strip
        #{message_history.present? ? "#{message_history}\n\n" : ''}Responde al siguiente mensaje de #{first_name}:
        "#{message_text}"

        Máximo 4 líneas. Tono natural y conversacional.
        No uses prefijos como "Asesor:" o "Bot:". No incluyas comillas al inicio ni al final.
      USER
    end

    def attachment_instructions
      'ENVÍO DE ARCHIVOS: Para enviar un archivo al cliente, escribe la directiva EXACTA (por ejemplo {{nombre}}) ' \
        'dentro de tu respuesta, tal cual y sin comillas; el sistema la sustituirá por el archivo adjunto. ' \
        'No la describas ni la traduzcas.'
    end

    private

    def generic_task
      <<~TASK.strip
        Genera un mensaje corto y natural para retomar contacto con el cliente.
        Dirígete al cliente por su nombre. Céntrate en el OBJETIVO.
        No des información extra ni repitas lo mismo que en mensajes anteriores.
        Genera solo el mensaje, sin explicaciones adicionales.
      TASK
    end
  end
end
