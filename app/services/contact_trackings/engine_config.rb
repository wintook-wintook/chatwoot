# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# ================================================================================
# Servicio: ContactTrackings::EngineConfig
# Descripción: Fuente única del modelo de IA y del tope de tokens del motor de
#              Seguimientos.
#
# EL PROBLEMA QUE RESUELVE:
#   La integración `tracking_bot` (hook_type: inbox) expone un selector obligatorio
#   "Modelo de IA" (`model_ia`) con cuatro opciones — ver config/integration/apps.yml.
#   Ese ajuste NO lo leía ningún archivo Ruby: los puntos de llamada a OpenAI
#   mandaban 'gpt-4o-mini' literal. El usuario elegía GPT-4o, se guardaba, se
#   veía en la pantalla de integraciones, y el agente seguía corriendo en el modelo
#   pequeño. Configuración fantasma.
#
# RESOLUCIÓN DEL MODELO (por inbox, que es la granularidad del hook):
#   hook tracking_bot del inbox → settings['model_ia'] → si no hay, DEFAULT_MODEL.
#   Se valida contra ALLOWED_MODELS para que un valor viejo o manipulado en la BD no
#   llegue a la API de OpenAI.
#
# ⚠ Cualquier punto nuevo que llame a OpenAI desde el motor de Seguimientos debe
#   resolver el modelo POR AQUÍ, nunca con una constante propia: si no, vuelve el
#   mismo defecto.
# ================================================================================

module ContactTrackings
  class EngineConfig
    # Decisión D1 (13/10/2026, P1 de docs/diagnostico_asistente_agentes_ia_plan.md): era
    # gpt-4o-mini, que está medido como que no cumple las reglas de un Entrenamiento largo
    # (KBase); todos los canales con agente IA ya habían elegido gpt-4o. Solo afecta a los
    # canales que no eligen modelo y a las llamadas sin canal.
    DEFAULT_MODEL = 'gpt-4o'

    # Espejo del enum de `model_ia` en config/integration/apps.yml. Si allí se agrega
    # un modelo, hay que agregarlo aquí (spec/services/contact_trackings/engine_config_spec.rb
    # lo verifica leyendo el YAML, para que no se desincronicen en silencio).
    #
    # Decisión D19 (13/10/2026, F0 del P1): gpt-5.5 se probó para contestar y NO se ofrece.
    # Con 3 agentes × 43 pruebas acertó las mismas rutas que gpt-4o y gpt-5.4-mini, sin
    # mejora medible, a 2,6× el costo de gpt-4o y con la llamada más lenta (2,4–3,7 s).
    # gpt-5.4-mini queda como opción económica: mismas rutas a ~⅓ del costo de gpt-4o.
    ALLOWED_MODELS = %w[gpt-4o-mini gpt-4o gpt-4-turbo gpt-3.5-turbo gpt-5.4-mini].freeze

    # Topes actuales de cada punto de llamada. Centralizarlos no cambia el
    # comportamiento — son los mismos valores que estaban en línea — pero deja el
    # presupuesto en un solo sitio.
    MAX_TOKENS = {
      scheduled: 150,       # ContactTrackingJob — mensaje programado de cada intento
      conversational: 250,  # respuesta al cliente
      router: 300,          # clasificador de intención (JSON)
      datetime: 120,        # extracción de fecha/hora (JSON)
      authoring: 250,       # redacción de complementary_prompt desde /sigue
      # proyecto@asistente_agentes_ia — un Entrenamiento entero, no una frase: el
      # tope de `authoring` (250) lo cortaría a la mitad.
      #
      # ⚠ Estaba en 2000, que alcanza para CREAR (~30 líneas) pero no para EDITAR:
      # devolver el v6.11 completo (17.066 caracteres) usó 4.365 y 4.421 tokens de
      # salida, medido el 15/09/2026. Con 2000 la respuesta llegaba cortada y el
      # turno fallaba sin decir por qué. 12000 cubre prompts de ~45.000 caracteres y
      # queda debajo del máximo de gpt-4o (16384). El tope no se cobra: se paga lo
      # que se genera.
      authoring_assistant: 12_000,
      # proyecto@solicitudes (pieza 5): la lista de servicios de un correo con 3–6 equipos,
      # cada uno con paradas, fecha, carga y folios.
      service_requests: 2500
    }.freeze

    # proyecto@asistente_agentes_ia — piso de modelo por propósito.
    #
    # Dos problemas que resuelve, los dos medidos:
    #   1. El Asistente de Agentes IA NO tiene inbox: es de cuenta. Sin piso,
    #      model_for(nil) cae a DEFAULT_MODEL (hasta el 13/10/2026, el modelo chico).
    #   2. gpt-4o-mini no cumple las reglas de un prompt largo (medido en KBase). El
    #      asistente escribe configuración que el motor parsea con patrones exactos:
    #      un modelo que se saltea reglas produce Entrenamientos que no ejecutan nada.
    #
    # Un piso NO fuerza el modelo: si el inbox configuró uno más capaz, ese gana.
    # service_requests: separar un correo en servicios sigue reglas finas («consolidar» = uno,
    # «entrega y recolección» = dos); el modelo chico se las salta.
    MODEL_FLOOR = { authoring_assistant: 'gpt-4o', service_requests: 'gpt-4o' }.freeze
    # Orden de capacidad, de menor a mayor. Solo para comparar contra el piso.
    MODEL_RANK = %w[gpt-3.5-turbo gpt-4o-mini gpt-4-turbo gpt-4o gpt-5.4-mini gpt-5.5].freeze

    # Decisión D18 (13/10/2026, P3b de docs/diagnostico_asistente_agentes_ia_plan.md): si el
    # canal elige un modelo gpt-5, solo lo usan los propósitos que CONTESTAN al cliente
    # (la Base de Conocimiento llama con :conversational). Clasificar rutas, entender
    # fechas, separar solicitudes, el ERP y redactar siguen con REASONING_FALLBACK: ya
    # funcionan bien, son rápidos, y el Asistente prueba el ruteo con ese clasificador.
    REPLY_PURPOSES = %i[conversational scheduled].freeze
    REASONING_FALLBACK = 'gpt-4o'

    class << self
      # El selector es uno por inbox y aplica a todo el bot. `purpose` existe para las
      # políticas que no pueden depender de esa configuración: hoy, el piso de
      # MODEL_FLOOR (ver ahí por qué).
      def model_for(inbox, purpose = :conversational)
        configured = configured_model(inbox)
        model = ALLOWED_MODELS.include?(configured) ? configured : DEFAULT_MODEL
        apply_floor(only_for_replies(model, purpose), purpose)
      end

      # Atajo para los llamadores que tienen el ContactTracking a mano.
      def model_for_tracking(tracking, purpose = :conversational)
        model_for(tracking&.inbox, purpose)
      end

      def max_tokens_for(purpose)
        MAX_TOKENS.fetch(purpose.to_sym, MAX_TOKENS[:conversational])
      end

      private

      def only_for_replies(model, purpose)
        return model unless model.match?(ContactTrackings::EngineOpenai::REASONING_MODEL_RE)

        REPLY_PURPOSES.include?(purpose.to_sym) ? model : REASONING_FALLBACK
      end

      # Sube al piso solo si el modelo resuelto queda por debajo; nunca lo baja.
      def apply_floor(model, purpose)
        floor = MODEL_FLOOR[purpose.to_sym]
        return model if floor.blank?

        MODEL_RANK.index(model).to_i < MODEL_RANK.index(floor).to_i ? floor : model
      end

      def configured_model(inbox)
        return nil if inbox.blank?

        inbox.account
             &.hooks
             &.find_by(app_id: 'tracking_bot', inbox_id: inbox.id, status: 'enabled')
             &.settings&.dig('model_ia').presence
      rescue StandardError => e
        # Fail-soft: que un problema leyendo la configuración nunca tumbe un envío.
        Rails.logger.warn "[EngineConfig] No se pudo resolver model_ia: #{e.message}"
        nil
      end
    end
  end
end
