# frozen_string_literal: true

require 'rails_helper'

# Campaña con IA — la encuesta que se contesta desde el correo (Public::CampaignSurveysController): abrir la liga no
# guarda nada (los antivirus las abren solos); al mandar, quedan las respuestas y el seguimiento cumplido.
RSpec.describe 'Public campaign surveys' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:contact) { create(:contact, account: account, name: 'Mario', email: 'mario@ejemplo.com') }
  let(:campaign) do
    account.tracking_campaigns.create!(name: 'Encuesta', engine: '2', status: 'running', tracking_template: seller, inbox: inbox, user: admin,
                                       scheduled_for: 1.day.ago, touches: { 'attempts' => 1 },
                                       brief: { 'kind' => 'survey', 'survey_questions' => ['Del 0 al 10, ¿nos recomiendas?', '¿Qué mejoramos?'] })
  end
  let(:tracking) do
    ContactTracking.create!(account: account, contact: contact, inbox: inbox, tracking_template: seller, tracking_campaign: campaign,
                            scheduled_for: 1.minute.from_now, status: 'active', max_attempts: 1, attempt_count: 1, objective: 'Encuesta')
  end
  let(:token) { TrackingCampaigns::SurveyLink.verifier.generate([tracking.id, 8]) }

  it 'abrir enseña las preguntas con la calificación elegida, sin guardar' do
    get "/encuesta/#{token}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('¿nos recomiendas?', 'value="8" selected')
    expect(tracking.reload.motor2_state['survey']).to be_nil
  end

  it 'al mandar guarda las respuestas y queda cumplido' do
    post "/encuesta/#{token}", params: { answers: { '0' => '8', '1' => 'Más rápido' } }
    expect(response).to have_http_status(:ok)
    expect(tracking.reload.motor2_state['survey']).to eq('1' => { 'respuesta' => '8', 'calificacion' => 8 }, '2' => { 'respuesta' => 'Más rápido' })
    expect(tracking.status).to eq('objective_met')
  end

  it 'un token alterado no abre nada' do
    get '/encuesta/otro'
    expect(response).to have_http_status(:not_found)
  end
end
