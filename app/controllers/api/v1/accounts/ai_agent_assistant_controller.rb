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

  private

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
