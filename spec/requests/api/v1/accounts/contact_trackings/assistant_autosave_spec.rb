# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — PUT …/assistant/autosave
RSpec.describe 'Asistente de Agentes IA — guardado automático' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:url)     { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/autosave" }

  it 'no deja entrar a un agente' do
    put url, params: { draft: 'x' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'sin conversación la crea, y con su id la sigue' do
    put url, params: { draft: "# Mi prompt\n[ROL]\nAmable." }, headers: admin.create_new_auth_token, as: :json
    id = response.parsed_body['session_id']

    put url, params: { draft: "# Mi prompt\n[ROL]\nAmable y breve.", session_id: id }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['session_id']).to eq(id)
    expect(TrackingAssistantSession.find(id)).to have_attributes(draft: "# Mi prompt\n[ROL]\nAmable y breve.", title: 'Mi prompt')
  end

  it 'no guarda un texto vacío' do
    put url, params: { draft: '  ' }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['error']).to eq('blank_draft')
  end
end
