# frozen_string_literal: true

# «Cómo habla tu empresa» — base común de Seguimiento IA y Agentes listos (no Agentes a medida).
# GET   /ai_voice           { voice: { who, tone, … }, fields: { who: 'Quiénes somos', … },
#                             business: { fixed: { what, … }, rows: [{ label, value }] } }
# PATCH /ai_voice           { voice: { … }, business: { … } } → guarda (los datos del negocio los usan
#                           también los agentes del Motor 2.0)
# POST  /ai_voice/preview   { voice: { … }, kind: 'follow_up' | 'prospects' } → { message } de ejemplo,
#                           con lo del formulario sin guardar; no manda nada.
# Solo administradores.
class Api::V1::Accounts::AiVoiceController < Api::V1::Accounts::BaseController
  before_action :require_admin

  def show
    render json: payload
  end

  def update
    AgentBase::CompanyVoice.update!(Current.account, voice_params)
    AgentBase::BusinessData.update!(Current.account, business_params) if params.key?(:business)
    render json: payload
  end

  def preview
    message = AgentBase::VoicePreview.new(Current.account, voice_params, kind: params[:kind]).call
    return render json: { error: 'No se pudo armar el ejemplo (¿la cuenta tiene OpenAI?).' }, status: :unprocessable_entity if message.blank?

    render json: { message: message }
  end

  private

  def require_admin
    render_access_denied unless access_grant.admin?
  end

  def voice_params
    params.fetch(:voice, {}).permit(*AgentBase::CompanyVoice::FIELDS.keys).to_h
  end

  def business_params
    params.fetch(:business, {}).permit(fixed: AgentBase::BusinessData::FIXED.keys, rows: %i[label value]).to_h
  end

  def payload
    { voice: AgentBase::CompanyVoice.get(Current.account), fields: AgentBase::CompanyVoice::FIELDS,
      business: AgentBase::BusinessData.get(Current.account), business_fields: AgentBase::BusinessData::FIXED }
  end
end
