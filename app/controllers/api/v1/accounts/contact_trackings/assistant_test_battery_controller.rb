# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — «PROBAR EL AGENTE» (M5 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# POST …/assistant/test_battery  (template_id, brief_id opcional)
#   Arranca la pila de pruebas en vivo del agente guardado (ver TestBatteryJob). 202 con
#   { id }. 422 { error: 'no_sandbox' } si la cuenta no tiene un canal API sin webhook donde
#   probar: ahí nunca se manda nada a un cliente.
#
# GET …/assistant/test_battery/:id
#   El avance y los resultados: { status, total, done, results[], … }.
#
# GET …/assistant/test_battery/:id/report
#   El informe en Markdown, para descargar.
#
# Mismo permiso que el resto del Asistente: administradores.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantTestBatteryController < Api::V1::Accounts::BaseController
  Battery = ContactTrackings::Assistant::TestBattery

  before_action :check_authorization
  before_action :fetch_state, only: [:show, :report]

  def show
    render json: @state
  end

  def create
    plantilla = Current.account.tracking_templates.find(params[:template_id])
    return render json: { error: 'no_sandbox' }, status: :unprocessable_entity if Battery.sandbox_inbox(Current.account).nil?

    encargo = params[:brief_id].present? ? TrackingAgentBrief.find_by(id: params[:brief_id], account: Current.account) : nil
    render json: { id: Battery.start(Current.account, plantilla, brief: encargo) }, status: :accepted
  end

  def report
    send_data Battery.report(@state).join("\n"), filename: "pila_#{@state['template_id']}_#{params[:id]}.md",
                                                 type: 'text/markdown; charset=utf-8', disposition: 'attachment'
  end

  private

  def fetch_state
    @state = Battery.read(params[:id])
    render json: { error: 'not_found' }, status: :not_found if @state.nil?
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
