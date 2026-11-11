# frozen_string_literal: true

require 'rails_helper'

# Agentes listos: catálogo, activar en una bandeja y pausar en la conversación.
RSpec.describe 'Ready Agents API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent_user) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp Ventas') }
  let(:api) { "/api/v1/accounts/#{account.id}" }
  let(:params) do
    { ready_agent: { kind: 'prospects', name: 'Sofi', enabled: true, inbox_ids: [inbox.id],
                     settings: { objective: 'handoff', questions: 'qué busca', only_prospects: 'false' } } }
  end

  it 'el catálogo trae prospectos disponible y los demás como próximamente' do
    get "#{api}/ready_agents", headers: admin.create_new_auth_token
    catalog = response.parsed_body['catalog']
    expect(catalog.first).to include('kind' => 'prospects', 'available' => true)
    expect(catalog.pluck('available').count(false)).to eq(3)
  end

  it 'lo activa en la bandeja con lo que se contestó' do
    post "#{api}/ready_agents", params: params, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    expect(ReadyAgent.last).to have_attributes(name: 'Sofi', enabled: true, inbox_ids: [inbox.id])
    expect(ReadyAgent.last.settings).to include('objective' => 'handoff', 'only_prospects' => false)
  end

  it 'guarda el negocio, las preguntas armadas, las objeciones y los datos a juntar' do
    settings = params[:ready_agent][:settings].merge(
      business_what: 'Paneles', business_use_catalog: 'true',
      qualify: [{ key: 'need', on: 'true', text: '' }, { key: 'budget', on: 'false', text: '¿Cuánto pagas?' }],
      objections: [{ objection: 'Está caro', answer: 'Se paga solo' }], required_contact: %w[email]
    )
    post "#{api}/ready_agents", params: { ready_agent: params[:ready_agent].merge(settings: settings) },
                                headers: admin.create_new_auth_token, as: :json

    saved = ReadyAgent.last.settings
    expect(saved).to include('business_what' => 'Paneles', 'business_use_catalog' => true, 'required_contact' => ['email'],
                             'objections' => [{ 'objection' => 'Está caro', 'answer' => 'Se paga solo' }])
    expect(saved['qualify']).to eq([{ 'key' => 'need', 'on' => true, 'text' => '' },
                                    { 'key' => 'budget', 'on' => false, 'text' => '¿Cuánto pagas?' }])
  end

  it 'prenderlo o apagarlo desde la lista no borra su configuración' do
    post "#{api}/ready_agents", params: params, headers: admin.create_new_auth_token, as: :json
    agent = ReadyAgent.last

    patch "#{api}/ready_agents/#{agent.id}", params: { ready_agent: { enabled: false } },
                                             headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(agent.reload.enabled).to be(false)
    expect(agent.settings).to include('objective' => 'handoff', 'questions' => 'qué busca', 'only_prospects' => false)
  end

  it 'solo administradores' do
    get "#{api}/ready_agents", headers: agent_user.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
  end

  it 'en la conversación se ve quién atiende y se pausa' do
    ready = ReadyAgent.create!(account: account, kind: 'prospects', name: 'Sofi', enabled: true, inbox_ids: [inbox.id])
    conversation = create(:conversation, account: account, inbox: inbox)
    session = ReadyAgentSession.create!(account: account, ready_agent: ready, conversation: conversation)

    get "#{api}/ready_agent_sessions", params: { conversation_id: conversation.display_id }, headers: admin.create_new_auth_token
    expect(response.parsed_body['session']).to include('status' => 'active', 'agent' => include('name' => 'Sofi'))

    patch "#{api}/ready_agent_sessions/#{session.id}/pause", headers: admin.create_new_auth_token
    expect(session.reload.status).to eq('paused')
  end
end
