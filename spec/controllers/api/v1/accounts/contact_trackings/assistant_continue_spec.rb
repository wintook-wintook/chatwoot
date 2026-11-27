# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — la API de «Continuar la conversación anterior».
RSpec.describe 'Asistente: continuar la conversación anterior', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:base) { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/sessions" }
  let(:template) { create(:tracking_template, account: account, complementary_prompt: "@ruta(info #info: algo): @buscar_articulo\n") }

  it 'sin anterior regresa null; con anterior la describe y la continúa' do
    get "#{base}/previous", params: { template_id: template.id }, headers: admin.create_new_auth_token
    expect(response.parsed_body).to be_nil

    anterior = TrackingAssistantSession.create!(account: account, user: admin, tracking_template: template, status: 'saved',
                                                messages: [{ 'role' => 'user', 'content' => 'hola' }])
    get "#{base}/previous", params: { template_id: template.id }, headers: admin.create_new_auth_token
    expect(response.parsed_body).to include('id' => anterior.id, 'messages_count' => 1, 'mine' => true)

    expect do
      post "#{base}/#{anterior.id}/continue", headers: admin.create_new_auth_token
    end.to change(TrackingAssistantSession.where(status: 'open'), :count).by(1)
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['messages'].size).to eq(2)
  end
end
