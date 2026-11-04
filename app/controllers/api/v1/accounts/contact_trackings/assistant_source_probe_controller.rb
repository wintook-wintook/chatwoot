# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando §15 — «PROBAR FUENTES»
# ================================================================================
# POST …/assistant/source_probe        { draft }  → { directives: [...] }
#   Lo que se puede probar del Entrenamiento (sin directivas: las fuentes de la cuenta).
# POST …/assistant/source_probe/run    { directive, phrase }
#   → { kind, threshold, threshold_from, max_results, results, used } o { error }
#   La búsqueda como la haría el agente (SourceProbe). Solo el embedding de la frase.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantSourceProbeController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    render json: { directives: probe.directives }
  end

  def run
    result = probe.run(params[:directive], params[:phrase])
    render json: result, status: result[:error] && result[:kind].nil? ? :unprocessable_entity : :ok
  end

  private

  def probe
    ContactTrackings::Assistant::SourceProbe.new(
      Current.account, text: params[:draft],
                       api_key: ContactTrackings::Assistant::OpenaiChat.new(account: Current.account).api_key
    )
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
