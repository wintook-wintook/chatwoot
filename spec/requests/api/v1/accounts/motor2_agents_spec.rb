# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — la ficha 2.0: crear, guardar con versión, restaurar, probar y «¿listo para atender?».
RSpec.describe 'Motor2 Agents API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent_user) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp Ventas') }
  let(:api) { "/api/v1/accounts/#{account.id}/motor2_agents" }
  let(:agent_params) do
    { name: 'Becas', customer_display_name: 'Sofi', objective: 'Inscribir alumnos en una carrera', inbox_id: inbox.id,
      attempts: 3, keyword_actions: [{ keyword: 'baja', action: 'cancel' }],
      motor2: { tone: 'usted', instructions: 'Habla de las carreras de la escuela', sources: ['canned_response'],
                business: [{ label: 'Horario', value: 'L-V 9 a 18' }, { label: '', value: 'se va' }],
                skills: { data: { on: true, fields: [{ key: 'Carrera', label: 'Carrera', ask: 'true', values: %w[Derecho] }] },
                          offers: { on: true, steps: [{ text: 'Beca de 20%' }, { text: '' }] }, raro: { on: true } } } }
  end

  def create_agent
    post api, params: { agent: agent_params }, headers: admin.create_new_auth_token, as: :json
    TrackingTemplate.last
  end

  it 'crea un agente 2.0 en la misma tabla de Agentes a medida, con su ficha limpia y su primera versión' do # rubocop:disable RSpec/MultipleExpectations
    template = create_agent
    expect(response).to have_http_status(:created)
    expect(template).to have_attributes(engine: '2', name: 'Becas', customer_display_name: 'Sofi', inbox_id: inbox.id)
    expect(template.follow_up_attempts).to eq(3)
    expect(template.motor2['business']).to eq([{ 'label' => 'Horario', 'value' => 'L-V 9 a 18' }])
    expect(template.motor2.dig('skills', 'data', 'fields', 0)).to include('key' => 'carrera', 'ask' => true)
    expect(template.motor2.dig('skills', 'offers', 'steps').size).to eq(1)
    expect(template.motor2['skills']).not_to have_key('raro')
    expect(Motor2Version.where(tracking_template: template).pluck(:version, :source)).to eq([[1, 'create']])
  end

  it 'guardar deja versión solo si cambió algo, y restaurar regresa a la anterior' do
    template = create_agent
    patch "#{api}/#{template.id}", params: { agent: { motor2: agent_params[:motor2].merge(instructions: 'Otra cosa') } },
                                   headers: admin.create_new_auth_token, as: :json
    patch "#{api}/#{template.id}", params: { agent: { motor2: agent_params[:motor2].merge(instructions: 'Otra cosa') } },
                                   headers: admin.create_new_auth_token, as: :json
    expect(Motor2Version.where(tracking_template: template).count).to eq(2)

    first = Motor2Version.find_by(tracking_template: template, version: 1)
    post "#{api}/#{template.id}/restore", params: { version_id: first.id }, headers: admin.create_new_auth_token, as: :json
    expect(template.reload.motor2['instructions']).to eq('Habla de las carreras de la escuela')
    expect(Motor2Version.where(tracking_template: template).ordered.first.source).to eq('restore')
  end

  it 'un agente 1.0 no se abre como 2.0' do
    old = create(:tracking_template, account: account)
    get "#{api}/#{old.id}", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)
  end

  it 'el chat de prueba contesta con lo de la pantalla sin guardar nada' do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    allow_any_instance_of(Motor2::Runner).to receive(:complete) # rubocop:disable RSpec/AnyInstance
      .and_return({ 'role' => 'assistant', 'content' => '¡Hola! ¿Qué carrera le interesa?' })

    expect do
      post "#{api}/test", params: { agent: agent_params, messages: [{ role: 'user', content: 'Hola' }] },
                          headers: admin.create_new_auth_token, as: :json
    end.not_to change(TrackingTemplate, :count)
    expect(response.parsed_body).to include('reply' => '¡Hola! ¿Qué carrera le interesa?')
    expect(response.parsed_body['trace']).to include('tools' => [])
  end

  it '¿listo para atender? y activar en su bandeja' do
    template = create_agent
    get "#{api}/#{template.id}/readiness", headers: admin.create_new_auth_token
    expect(response.parsed_body['items'].pluck('key')).to include('openai', 'channel', 'assignment')

    post "#{api}/#{template.id}/activate", headers: admin.create_new_auth_token
    rule = account.automation_rules.last
    expect(rule.actions.first).to include('action_name' => 'assign_tracking_template', 'action_params' => [template.id])
  end

  it 'solo administradores' do
    get "#{api}/options", headers: agent_user.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
  end
end
