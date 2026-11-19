# frozen_string_literal: true

require 'rails_helper'

# Agentes listos: catálogo de funciones, crear un agente con su asistente (queda en la lista de
# agentes, motor 2.0 — Plan-Motor-Agentes §11.14.5), chat de prueba y pausar en la conversación.
RSpec.describe 'Ready Agents API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent_user) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp Ventas') }
  let(:api) { "/api/v1/accounts/#{account.id}" }
  let(:params) do
    { ready_agent: { kind: 'prospects', name: 'Prospectos Facebook', display_name: 'Sofi', enabled: true, inbox_ids: [inbox.id],
                     settings: { objective: 'handoff', questions: 'qué busca', only_prospects: 'false', instructions: 'Sé breve' } } }
  end

  def create_agent(extra = {})
    post "#{api}/ready_agents", params: { ready_agent: params[:ready_agent].merge(extra) }, headers: admin.create_new_auth_token, as: :json
    account.tracking_templates.find(response.parsed_body.dig('agent', 'id'))
  end

  it 'el catálogo trae «Atención a prospectos» disponible y las demás funciones como próximamente' do
    get "#{api}/ready_agents", headers: admin.create_new_auth_token
    catalog = response.parsed_body['catalog']
    expect(catalog.first).to include('kind' => 'prospects', 'title' => 'Atención a prospectos', 'available' => true)
    expect(catalog.pluck('available').count(false)).to eq(3)
  end

  it 'lo crea como agente 2.0 de la lista, con lo que se contestó' do
    template = create_agent

    expect(response).to have_http_status(:created)
    expect(template).to have_attributes(name: 'Prospectos Facebook', customer_display_name: 'Sofi', engine: '2',
                                        agent_function: 'prospects', attending: true, attend_inbox_ids: [inbox.id])
    expect(template.motor2['answers']).to include('objective' => 'handoff', 'only_prospects' => false)
    expect(template.motor2['instructions']).to eq('Sé breve')
    expect(response.parsed_body['agent']).to include('kind' => 'prospects', 'enabled' => true, 'inbox_ids' => [inbox.id],
                                                     'settings' => include('instructions' => 'Sé breve'))
  end

  it 'se pueden tener varios del mismo tipo (en bandejas distintas)' do
    create_agent
    other_inbox = create(:inbox, account: account)
    create_agent(name: 'Prospectos página', inbox_ids: [other_inbox.id])

    get "#{api}/ready_agents", headers: admin.create_new_auth_token
    expect(response.parsed_body['agents'].pluck('name')).to contain_exactly('Prospectos Facebook', 'Prospectos página')
  end

  it 'guarda el negocio, las preguntas armadas, las objeciones y los datos a juntar' do
    settings = params[:ready_agent][:settings].merge(
      business_what: 'Paneles', business_use_catalog: 'true',
      qualify: [{ key: 'need', on: 'true', text: '' }, { key: 'budget', on: 'false', text: '¿Cuánto pagas?' }],
      objections: [{ objection: 'Está caro', answer: 'Se paga solo' }], required_contact: %w[email]
    )
    saved = create_agent(settings: settings).motor2['answers']

    expect(saved).to include('business_what' => 'Paneles', 'business_use_catalog' => true, 'required_contact' => ['email'],
                             'objections' => [{ 'objection' => 'Está caro', 'answer' => 'Se paga solo' }])
    expect(saved['qualify']).to eq([{ 'key' => 'need', 'on' => true, 'text' => '' },
                                    { 'key' => 'budget', 'on' => false, 'text' => '¿Cuánto pagas?' }])
  end

  it 'prenderlo o apagarlo desde la lista no borra su configuración' do
    template = create_agent

    patch "#{api}/ready_agents/#{template.id}", params: { ready_agent: { enabled: false } },
                                                headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(template.reload.attending).to be(false)
    expect(template.motor2['answers']).to include('objective' => 'handoff', 'questions' => 'qué busca', 'only_prospects' => false)
    expect(template.motor2['instructions']).to eq('Sé breve')
  end

  it 'en la lista de agentes sale con su función y se abre con su asistente' do
    template = create_agent
    get "#{api}/tracking_templates", headers: admin.create_new_auth_token

    row = response.parsed_body.find { |t| t['id'] == template.id }
    expect(row).to include('function_title' => 'Atención a prospectos', 'agent_function' => 'prospects')
  end

  it 'borrar uno en uso lo archiva: deja de atender y sale de las listas' do
    template = create_agent
    create(:contact_tracking, account: account, inbox: inbox, tracking_template: template, status: 'active')

    delete "#{api}/ready_agents/#{template.id}", headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(template.reload).to have_attributes(attending: false, archived_at: be_present)
    get "#{api}/tracking_templates", headers: admin.create_new_auth_token
    expect(response.parsed_body.pluck('id')).not_to include(template.id)
  end

  it 'chat de prueba con el motor 2.0, sin guardar nada' do
    allow_any_instance_of(Motor2::Runner).to receive(:complete).and_return({ 'role' => 'assistant', 'content' => '¡Hola! ¿Qué buscas?' }) # rubocop:disable RSpec/AnyInstance
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })

    expect do
      post "#{api}/ready_agents/test", params: params.merge(messages: [{ role: 'user', content: 'Hola' }], state: {}),
                                       headers: admin.create_new_auth_token, as: :json
    end.not_to change(TrackingTemplate, :count)
    expect(response.parsed_body).to include('reply' => '¡Hola! ¿Qué buscas?', 'tools' => [])
  end

  it 'solo administradores' do
    get "#{api}/ready_agents", headers: agent_user.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
  end

  it 'en la conversación se ve quién atiende y se pausa y reanuda' do
    template = create_agent
    conversation = create(:conversation, account: account, inbox: inbox)
    tracking = create(:contact_tracking, account: account, inbox: inbox, contact: conversation.contact, conversation: conversation,
                                         tracking_template: template, status: 'active', motor2_state: { 'answers' => { 'Ciudad' => 'MTY' } })

    get "#{api}/ready_agent_sessions", params: { conversation_id: conversation.display_id }, headers: admin.create_new_auth_token
    expect(response.parsed_body['session']).to include('id' => "t#{tracking.id}", 'status' => 'active', 'answers' => { 'Ciudad' => 'MTY' },
                                                       'agent' => include('name' => 'Prospectos Facebook'))

    patch "#{api}/ready_agent_sessions/t#{tracking.id}/pause", headers: admin.create_new_auth_token
    expect(tracking.reload.status).to eq('paused')
    patch "#{api}/ready_agent_sessions/t#{tracking.id}/resume", headers: admin.create_new_auth_token
    expect(tracking.reload.status).to eq('active')
  end
end
