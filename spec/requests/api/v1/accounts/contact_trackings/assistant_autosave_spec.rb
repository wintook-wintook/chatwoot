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

  describe 'renombrar' do
    let(:sesion) do
      TrackingAssistantSession.create!(account: account, user: admin, draft: "# PROMPT X\n[ROL]\nx",
                                       messages: [{ 'role' => 'user', 'content' => 'Analiza mi prompt' }])
    end
    let(:rename_url) { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/sessions/#{sesion.id}/name" }

    it 'el nombre manda sobre el título automático; vacío lo quita' do
      expect(sesion.title).to eq('🔎 PROMPT X')

      patch rename_url, params: { name: 'Universidad — becas' }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('title' => 'Universidad — becas', 'named' => true)

      patch rename_url, params: { name: '' }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('title' => '🔎 PROMPT X', 'named' => false)
    end

    it 'no renombra una conversación de otra cuenta' do
      otra = create(:account)
      ajena = TrackingAssistantSession.create!(account: otra, user: create(:user, account: otra))
      patch "/api/v1/accounts/#{account.id}/contact_trackings/assistant/sessions/#{ajena.id}/name",
            params: { name: 'x' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
