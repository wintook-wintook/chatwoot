# frozen_string_literal: true

require 'rails_helper'

# proyecto@diagrama_agente_ia F3
RSpec.describe 'Api::V1::Accounts::ContactTrackings::AssistantTestCasesController', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:template) { create(:tracking_template, account: account, complementary_prompt: "@ruta(cotizar #cotizar: precios): -\n") }
  let(:base_url) { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/test_cases" }
  let(:headers) { admin.create_new_auth_token }

  it 'solo administradores' do
    get base_url, params: { template_id: template.id }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'agrega, fija, lista y borra' do
    post base_url, params: { template_id: template.id, message: '¿precio?' }, headers: headers, as: :json
    id = response.parsed_body['id']
    expect(response).to have_http_status(:created)

    patch "#{base_url}/#{id}", params: { pinned: true }, headers: headers, as: :json
    get base_url, params: { template_id: template.id }, headers: headers, as: :json
    expect(response.parsed_body['cases'].first).to include('message' => '¿precio?', 'pinned' => true)
    expect(response.parsed_body['live_offer']['case_ids']).to eq([id])

    delete "#{base_url}/#{id}", headers: headers, as: :json
    expect(template.test_cases.count).to eq(0)
  end

  it 'no deja tocar la pila de otra cuenta' do
    ajena = create(:tracking_template)

    get base_url, params: { template_id: ajena.id }, headers: headers, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'corre en seco toda la pila contra el borrador' do
    template.test_cases.create!(account: account, message: 'hola')
    allow(ContactTrackings::Assistant::TestCasesDryJob).to receive(:perform_later)

    post "#{base_url}/run_dry", params: { template_id: template.id, draft: 'otro texto' }, headers: headers, as: :json

    expect(response).to have_http_status(:accepted)
    expect(ContactTrackings::Assistant::TestCasesDryJob).to have_received(:perform_later)
      .with(account.id, template.id, 'otro texto', nil, 'manual')
  end

  it 'en vivo pide un canal de pruebas' do
    caso = template.test_cases.create!(account: account, message: 'hola')

    post "#{base_url}/run_live", params: { template_id: template.id, case_ids: [caso.id] }, headers: headers, as: :json

    expect(response.parsed_body['error']).to eq('no_sandbox')
  end

  it 'en vivo manda las pruebas elegidas a la pila' do
    create(:inbox, account: account, channel: create(:channel_api, account: account, webhook_url: ''))
    caso = template.test_cases.create!(account: account, message: 'hola')
    allow(ContactTrackings::Assistant::TestBatteryJob).to receive(:perform_later)

    post "#{base_url}/run_live", params: { template_id: template.id, case_ids: [caso.id] }, headers: headers, as: :json

    expect(response).to have_http_status(:accepted)
    expect(ContactTrackings::Assistant::TestBatteryJob).to have_received(:perform_later)
      .with(anything, account.id, template.id, nil, nil, [caso.id])
  end

  it 'al publicar corre la pila en seco contra lo publicado (D5)' do
    allow(ContactTrackings::Assistant::TestCasesDryJob).to receive(:perform_later)
    template.test_cases.create!(account: account, message: 'hola')

    ContactTrackings::Assistant::TestCases.after_publish(account, template)

    expect(ContactTrackings::Assistant::TestCasesDryJob).to have_received(:perform_later)
      .with(account.id, template.id, template.complementary_prompt, template.inbox_id, 'publish')
  end

  # F5
  it 'agrega un diálogo' do
    post base_url, params: { template_id: template.id, message: 'x', turns: ['quiero cita', 'el martes'] },
                   headers: headers, as: :json

    expect(response.parsed_body).to include('message' => 'quiero cita', 'turns' => ['quiero cita', 'el martes'])
  end

  it 'compara la pila contra una versión guardada' do
    template.test_cases.create!(account: account, message: 'hola')
    version = template.versions.create!(account: account, version: 3, snapshot: { 'complementary_prompt' => 'v3' })
    allow(ContactTrackings::Assistant::TestCasesCompareJob).to receive(:perform_later)

    post "#{base_url}/compare", params: { template_id: template.id, version_id: version.id, draft: 'ahora' },
                                headers: headers, as: :json

    expect(response).to have_http_status(:accepted)
    expect(ContactTrackings::Assistant::TestCasesCompareJob).to have_received(:perform_later)
      .with(account.id, template.id, version.id, 'ahora', nil)
  end
end
