# frozen_string_literal: true

require 'rails_helper'

# @kbase_contpaq — el alta de la fuente desde la pantalla de Fuentes de Conocimiento.
RSpec.describe 'Knowledge Base API — fuente CONTPAQi', type: :request do
  let!(:account) { create(:account) }
  let(:admin)    { create(:user, account: account, role: :administrator) }

  let(:payload) do
    { knowledge_source: {
      name: 'Agente de Servicio CONTPAQi', source_type: 'contpaq_support',
      config: { base_url: 'https://apim.test/v1', token_url: 'https://login.test/token',
                client_id: 'cid', client_secret: 'secret', scope: 'api://x/.default' }
    } }
  end

  def post_source(body = payload)
    post "/api/v1/accounts/#{account.id}/knowledge_base/sources",
         params: body, headers: admin.create_new_auth_token, as: :json
  end

  it 'crea la fuente con sus credenciales' do
    post_source

    expect(response).to have_http_status(:created)
    source = account.knowledge_sources.find_by(source_type: 'contpaq_support')
    expect(source.name).to eq('Agente de Servicio CONTPAQi')
    expect(source.config).to include('client_id' => 'cid', 'scope' => 'api://x/.default')
  end

  it 'no le pide la feature de Google, que no usa' do
    # El alta de Docs/Sheets exige google_calendar; esta fuente no depende de Google.
    expect(account.feature_enabled?('google_calendar')).to be(false)
    post_source
    expect(response).to have_http_status(:created)
  end

  it 'no encola sincronizacion: se consulta en vivo, no hay copia local' do
    expect { post_source }.not_to change(KnowledgeItem, :count)
    expect(account.knowledge_sources.find_by(source_type: 'contpaq_support').last_synced_at).to be_nil
  end

  it 'rechaza un nombre repetido, porque la directiva direcciona por nombre' do
    post_source
    post_source

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.knowledge_sources.where(source_type: 'contpaq_support').count).to eq(1)
  end
end
