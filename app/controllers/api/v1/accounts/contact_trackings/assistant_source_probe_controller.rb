# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando §15 — «PROBAR FUENTES»
# ================================================================================
# POST …/assistant/source_probe        { draft }  → { directives: [...] }
#   Lo que se puede probar del Entrenamiento (sin directivas: las fuentes de la cuenta).
# POST …/assistant/source_probe/run    { directive, phrase, inbox_id?, rfc? }
#   → { kind, … } o { error }: la búsqueda como la haría el agente (SourceProbe).
#   Por parecido, solo el embedding de la frase; la hoja en modo datos y la consulta con
#   «?» gastan además una llamada de IA (la lista lo dice con `uses_ai`). En vivo (P3):
#   el foro se consulta tal cual; CONTPAQi abre un hilo de prueba (`notice`).
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantSourceProbeController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    render json: { directives: probe.directives }
  end

  def run
    result = probe.run(params[:directive], params[:phrase])
    render json: result, status: result[:error] && result[:kind].nil? ? :unprocessable_entity : :ok
  rescue StandardError => e
    Rails.logger.error "[Asistente] probar fuente: #{e.message}"
    render json: { error: 'failed' }, status: :unprocessable_entity
  end

  private

  def probe
    ContactTrackings::Assistant::SourceProbe.new(
      Current.account, text: params[:draft], rfc: params[:rfc], user: Current.user,
                       inbox: Current.account.inboxes.find_by(id: params[:inbox_id]),
                       api_key: ContactTrackings::Assistant::OpenaiChat.new(account: Current.account).api_key
    )
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
