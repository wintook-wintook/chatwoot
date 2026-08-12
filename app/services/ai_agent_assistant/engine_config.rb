# frozen_string_literal: true

# ================================================================================
# proyecto@ai_agent_assistant - F0
# ================================================================================
# Servicio: AiAgentAssistant::EngineConfig
# Descripción: Fuente única del modelo de IA y del tope de tokens del motor de
#              Seguimientos.
#
# EL PROBLEMA QUE RESUELVE:
#   La integración `tracking_bot` (hook_type: inbox) expone un selector obligatorio
#   "Modelo de IA" (`model_ia`) con cuatro opciones — ver config/integration/apps.yml.
#   Hasta F0 ese ajuste NO lo leía ningún archivo Ruby: los 5 puntos de llamada a
#   OpenAI mandaban 'gpt-4o-mini' literal. El usuario elegía GPT-4o, se guardaba, se
#   veía en la pantalla de integraciones, y el agente seguía corriendo en el modelo
#   pequeño. Configuración fantasma.
#
# RESOLUCIÓN DEL MODELO (por inbox, que es la granularidad del hook):
#   hook tracking_bot del inbox → settings['model_ia'] → si no hay, DEFAULT_MODEL.
#   Se valida contra ALLOWED_MODELS para que un valor viejo o manipulado en la BD no
#   llegue a la API de OpenAI.
#
# ⚠ El probador del Asistente debe resolver el modelo POR AQUÍ, nunca con una
#   constante propia: si no, la simulación deja de reproducir lo que ocurre de verdad.
# ================================================================================

class AiAgentAssistant::EngineConfig
  DEFAULT_MODEL = 'gpt-4o-mini'

  # Espejo del enum de `model_ia` en config/integration/apps.yml. Si allí se agrega
  # un modelo, hay que agregarlo aquí (spec/services/ai_agent_assistant/engine_config_spec.rb
  # lo verifica leyendo el YAML, para que no se desincronicen en silencio).
  ALLOWED_MODELS = %w[gpt-4o-mini gpt-4o gpt-4-turbo gpt-3.5-turbo].freeze

  # Topes actuales de cada punto de llamada. Centralizarlos no cambia el
  # comportamiento — son los mismos valores que estaban en línea — pero deja el
  # presupuesto en un solo sitio para que el linter y el probador puedan citarlo.
  MAX_TOKENS = {
    scheduled: 150,       # ContactTrackingJob — mensaje programado de cada intento
    conversational: 250,  # respuesta al cliente
    router: 300,          # clasificador de intención (JSON)
    datetime: 120,        # extracción de fecha/hora (JSON)
    authoring: 250        # redacción de complementary_prompt desde /sigue
  }.freeze

  class << self
    # `purpose` no diferencia el modelo hoy: el selector es uno por inbox y aplica a
    # todo el bot. Se recibe igualmente para que una política futura (por ejemplo,
    # forzar un modelo barato en el router) tenga dónde vivir sin tocar los llamadores.
    def model_for(inbox, _purpose = :conversational)
      configured = configured_model(inbox)
      ALLOWED_MODELS.include?(configured) ? configured : DEFAULT_MODEL
    end

    # Atajo para los llamadores que tienen el ContactTracking a mano.
    def model_for_tracking(tracking, purpose = :conversational)
      model_for(tracking&.inbox, purpose)
    end

    def max_tokens_for(purpose)
      MAX_TOKENS.fetch(purpose.to_sym, MAX_TOKENS[:conversational])
    end

    private

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
