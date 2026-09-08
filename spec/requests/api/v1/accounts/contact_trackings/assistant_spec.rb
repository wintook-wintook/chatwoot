# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia
RSpec.describe 'Asistente de Agentes IA — inventario' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:url)     { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/inventory" }

  def source(source_type, name)
    KnowledgeSource.create!(account: account, source_type: source_type, name: name, status: 'active')
  end

  it 'exige autenticación' do
    get url, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  # El inventario expone mensajes entrantes reales de la cuenta, así que no es
  # material para cualquier agente.
  it 'no deja entrar a un agente' do
    get url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'devuelve las fuentes con la directiva que hay que escribir en la @ruta' do
    source('discourse', 'Foro Kontrolya')

    get url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['sources']).to contain_exactly(
      hash_including('directive' => '@buscar_foro(Foro Kontrolya)', 'mode' => 'knowledge_source')
    )
  end

  it 'devuelve los tipos de caso, que son los válidos para @crear_ticket' do
    CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')

    get url, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['case_types']).to eq(['Soporte'])
  end

  it 'marca la cuenta vacía cuando no hay nada que ofrecer' do
    get url, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['empty']).to be(true)
  end

  it 'no filtra fuentes de otra cuenta' do
    otra = create(:account)
    KnowledgeSource.create!(account: otra, source_type: 'discourse', name: 'Foro Ajeno', status: 'active')

    get url, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['sources']).to be_empty
  end

  describe 'filtro por inbox' do
    let(:inbox_a) { create(:inbox, account: account) }
    let(:inbox_b) { create(:inbox, account: account) }

    def incoming(inbox, content)
      conversation = create(:conversation, account: account, inbox: inbox)
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       message_type: :incoming, content: content)
    end

    it 'acota las frases de clientes al inbox pedido' do
      incoming(inbox_a, 'como puedo actualizar a la ultima version')
      incoming(inbox_b, 'quiero agendar una demostracion para un cliente')

      get url, params: { inbox_id: inbox_a.id }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['customer_phrases']).to eq(['como puedo actualizar a la ultima version'])
    end

    it 'ignora un inbox_id que no es de la cuenta en vez de fallar' do
      incoming(inbox_a, 'como puedo actualizar a la ultima version')
      ajeno = create(:inbox, account: create(:account))

      get url, params: { inbox_id: ajeno.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['customer_phrases']).to eq(['como puedo actualizar a la ultima version'])
    end
  end
end
