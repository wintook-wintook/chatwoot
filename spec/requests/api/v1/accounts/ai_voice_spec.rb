# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cómo habla tu empresa API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_voice" }

  it 'el administrador lo lee y lo guarda' do
    patch url, params: { voice: { tone: 'De usted', signature: '— Equipo' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)

    get url, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['voice']).to include('tone' => 'De usted', 'signature' => '— Equipo')
    expect(response.parsed_body['fields']).to include('who' => 'Quiénes somos')
  end

  it 'guarda los datos del negocio de la cuenta (para todos los agentes)' do
    business = { fixed: { what: 'Paneles solares', why: '' }, rows: [{ label: 'Horario', value: 'L-V 9 a 18' }, { label: '', value: 'x' }] }
    patch url, params: { voice: { tone: 'De usted' }, business: business }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['business']).to eq('fixed' => { 'what' => 'Paneles solares', 'who' => '', 'coverage' => '', 'why' => '',
                                                                'practical' => '' },
                                                   'rows' => [{ 'label' => 'Horario', 'value' => 'L-V 9 a 18' }])
    expect(AgentBase::BusinessData.block(account.reload)).to include('- Qué vende: Paneles solares', '- Horario: L-V 9 a 18')
  end

  it 'si la cuenta nunca los guardó, salen de «Tu negocio» del Agente listo' do
    inbox = create(:inbox, account: account)
    ReadyAgent.create!(account: account, kind: 'prospects', name: 'Sofi', enabled: false, inbox_ids: [inbox.id],
                       settings: { 'business_what' => 'Paneles', 'business_coverage' => 'Monterrey' })
    get url, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('business', 'fixed')).to include('what' => 'Paneles', 'coverage' => 'Monterrey')
  end

  it 'guardar solo el tono no borra los datos del negocio' do
    AgentBase::BusinessData.update!(account, 'rows' => [{ 'label' => 'Horario', 'value' => '9 a 18' }])
    patch url, params: { voice: { tone: 'De tú' } }, headers: admin.create_new_auth_token, as: :json
    expect(AgentBase::BusinessData.get(account.reload)['rows']).to eq([{ 'label' => 'Horario', 'value' => '9 a 18' }])
  end

  it 'un agente no lo puede cambiar' do
    patch url, params: { voice: { tone: 'x' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized).or have_http_status(:forbidden)
  end

  it 'probar arma un ejemplo sin guardar' do
    allow_any_instance_of(AgentBase::VoicePreview).to receive(:chat).and_return('Hola — Equipo') # rubocop:disable RSpec/AnyInstance
    post "#{url}/preview", params: { voice: { signature: '— Equipo' }, kind: 'prospects' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['message']).to eq('Hola — Equipo')
    expect(AgentBase::CompanyVoice.get(account.reload)['signature']).to eq('')
  end
end
