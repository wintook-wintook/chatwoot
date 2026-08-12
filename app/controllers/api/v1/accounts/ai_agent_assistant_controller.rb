# ================================================================================
# proyecto@ai_agent_assistant - F1
# ================================================================================
# Controlador: AiAgentAssistantController
# Descripción: Superficie del Asistente de Agentes IA (account-scoped).
# Acciones: capabilities (catálogo resuelto contra el estado real de la cuenta),
#           lint, preview_prompt, patterns (biblioteca de bloques, F6),
#           simulate, auto_conversation, replay, compare (evaluación, F7).
#
# Devuelve estructura + `i18n_key`; los textos los pone el frontend desde
# aiAgentAssistant.json (código en inglés, UI en español con `en` completo).
# ================================================================================

class Api::V1::Accounts::AiAgentAssistantController < Api::V1::Accounts::BaseController
  def capabilities
    render json: {
      capabilities: AiAgentAssistant::Capabilities.resolve_for(
        account: Current.account,
        inbox: fetch_inbox,
        template: fetch_template,
        # Solo el catálogo lo pide: recorre todos los agentes de la cuenta.
        with_usage: params[:with_usage].present?
      ),
      engine: {
        model: AiAgentAssistant::EngineConfig.model_for(fetch_inbox),
        default_model: AiAgentAssistant::EngineConfig::DEFAULT_MODEL,
        max_tokens: AiAgentAssistant::EngineConfig::MAX_TOKENS
      }
    }
  end

  # F6 — Biblioteca de patrones: bloques insertables sacados de los agentes de
  # producción que sí funcionan. Se resuelven contra la cuenta Y contra el prompt
  # que se está escribiendo: un bloque de voz propia en un agente con `@discourse`
  # sale marcado como letra muerta en vez de ofrecerse.
  def patterns
    render json: AiAgentAssistant::PatternLibrary.for(
      account: Current.account,
      inbox: fetch_inbox,
      template: fetch_template,
      prompt: params[:complementary_prompt]
    )
  end

  # Valida un BORRADOR: no persiste nada. Si viene `id`, se parte del Agente IA
  # guardado y se le aplican encima los campos editados, para poder resolver cosas
  # que dependen del registro (sus archivos adjuntos, sus hermanos de versión).
  def lint
    render json: {
      findings: AiAgentAssistant::Linter.new(draft, account: Current.account).call
    }
  end

  # El «Ver prompt» del probador: ensambla lo que recibiría el modelo en las dos
  # rutas, para el intento indicado. No llama a OpenAI ni persiste nada.
  def preview_prompt
    render json: AiAgentAssistant::PromptPreview.new(
      draft,
      attempt: params[:attempt],
      contact_name: params[:contact_name],
      message: params[:message]
    ).call
  end

  # F7 — El turno EN VIVO. Con `message` es la respuesta del agente a ese mensaje
  # (con la ruta real del router); sin él, el mensaje inicial del intento pedido.
  # Ejecuta los motores de verdad con el envío desconectado: nada se persiste.
  def simulate
    sandbox = AiAgentAssistant::SandboxService.new(
      draft, contact_name: params[:contact_name], attempt: params[:attempt]
    )

    render json: params[:message].present? ? sandbox.reply(params[:message], history: params[:history].to_s) : sandbox.opening
  end

  # F7 — Un segundo modelo hace de cliente y conversa solo. Detecta bucles.
  def auto_conversation
    render json: AiAgentAssistant::AutoConversation.new(
      draft, persona: params[:persona], turns: params[:turns]
    ).call
  end

  # F7 — Contra mensajes reales de conversaciones cerradas de ese inbox, con la
  # respuesta humana al lado. La evaluación honesta.
  def replay
    render json: AiAgentAssistant::Replay.new(draft, limit: params[:limit]).call
  end

  # F7 — A/B: el mismo mensaje contra dos versiones del agente, lado a lado.
  def compare
    message = params[:message].presence
    render json: {
      message: message,
      a: run_variant(draft, message),
      b: run_variant(draft(:variant), message)
    }
  end

  private

  def run_variant(template, message)
    sandbox = AiAgentAssistant::SandboxService.new(template, attempt: params[:attempt])
    message ? sandbox.reply(message) : sandbox.opening
  end

  def draft(key = :tracking_template)
    base = if params[:id].present?
             Current.account.tracking_templates.find_by(id: params[:id]) || Current.account.tracking_templates.new
           else
             Current.account.tracking_templates.new
           end

    base.assign_attributes(draft_params(key))
    base
  end

  def draft_params(key = :tracking_template)
    params.fetch(key, {}).permit(
      :name, :objective, :ai_context, :complementary_prompt, :inbox_id, :timezone,
      :slots_presentation, :retry_interval_value, :retry_interval_unit,
      keyword_actions: [:keyword, :action, :direction],
      whatsapp_templates: {},
      calendar_integration_ids: []
    )
  end

  # El inbox acota lo que de verdad está disponible: el modelo de IA y la
  # integración de Discourse se configuran por inbox, no por cuenta.
  def fetch_inbox
    return @fetch_inbox if defined?(@fetch_inbox)

    @fetch_inbox = params[:inbox_id].present? ? Current.account.inboxes.find_by(id: params[:inbox_id]) : nil
  end

  # Con una plantilla concreta se puede además resolver el estado de sus adjuntos.
  def fetch_template
    return @fetch_template if defined?(@fetch_template)

    id = params[:tracking_template_id]
    @fetch_template = id.present? ? Current.account.tracking_templates.find_by(id: id) : nil
  end
end
