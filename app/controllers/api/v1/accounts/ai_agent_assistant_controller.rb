# ================================================================================
# proyecto@ai_agent_assistant - F1
# ================================================================================
# Controlador: AiAgentAssistantController
# Descripción: Superficie del Asistente de Agentes IA (account-scoped).
# Acciones: capabilities — catálogo resuelto contra el estado real de la cuenta.
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
        template: fetch_template
      ),
      engine: {
        model: AiAgentAssistant::EngineConfig.model_for(fetch_inbox),
        default_model: AiAgentAssistant::EngineConfig::DEFAULT_MODEL,
        max_tokens: AiAgentAssistant::EngineConfig::MAX_TOKENS
      }
    }
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

  private

  def draft
    base = if params[:id].present?
             Current.account.tracking_templates.find_by(id: params[:id]) || Current.account.tracking_templates.new
           else
             Current.account.tracking_templates.new
           end

    base.assign_attributes(draft_params)
    base
  end

  def draft_params
    params.fetch(:tracking_template, {}).permit(
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
