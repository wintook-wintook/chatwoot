# frozen_string_literal: true

require 'rails_helper'

# @knowledge_sources — endpoints de la fuente WordPress
RSpec.describe 'Base de Conocimiento — fuente WordPress' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:site)    { 'https://misitio.com' }

  def stub_wp(path, body, headers: {}, status: 200)
    stub_request(:get, "#{site}#{path}")
      .with(query: hash_including({}))
      .to_return(status: status, body: body.to_json,
                 headers: { 'Content-Type' => 'application/json' }.merge(headers))
  end

  def source_with(config)
    KnowledgeSource.create!(account: account, source_type: 'wordpress', name: 'Blog',
                            status: 'active', config: { 'site_url' => site }.merge(config))
  end

  describe 'POST wordpress_probe' do
    let(:url) { "/api/v1/accounts/#{account.id}/knowledge_base/wordpress_probe" }

    def probar(site_url, user: admin)
      post url, params: { site_url: site_url }, headers: user.create_new_auth_token, as: :json
    end

    it 'exige autenticación' do
      post url, params: { site_url: site }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'devuelve cuánto contenido tiene el sitio y sus categorías' do
      stub_wp('/wp-json/wp/v2/posts', [], headers: { 'X-WP-Total' => '1106' })
      stub_wp('/wp-json/wp/v2/pages', [], headers: { 'X-WP-Total' => '24' })
      stub_wp('/wp-json/wc/store/v1/products', {}, status: 404)
      stub_wp('/wp-json/wp/v2/categories', [{ 'id' => 3, 'name' => 'Soporte', 'count' => 113 }])

      probar(site)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['counts']).to include('posts' => 1106, 'pages' => 24, 'products' => nil)
      expect(response.parsed_body['categories'].first).to include('name' => 'Soporte')
    end

    # Hay instalaciones que bloquean la API REST por plugin de seguridad. Tiene que
    # verse ACÁ, antes de crear la fuente, y no con un agente ya en producción.
    it 'avisa cuando el sitio bloquea la API' do
      stub_wp('/wp-json/wp/v2/posts', {}, status: 403)

      probar(site)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('forbidden')
    end

    it 'avisa cuando el sitio no responde' do
      stub_request(:get, /#{site}/).to_timeout

      probar(site)

      expect(response.parsed_body['error']).to eq('unreachable')
    end
  end

  describe 'GET wordpress_catalog' do
    def catalogo(source, type: 'posts')
      get "/api/v1/accounts/#{account.id}/knowledge_base/sources/#{source.id}/wordpress_catalog",
          params: { type: type }, headers: admin.create_new_auth_token, as: :json
    end

    it 'devuelve los títulos con la marca de si entran o no' do
      source = source_with('content_types' => ['posts'], 'excluded_ids' => [2])
      stub_wp('/wp-json/wp/v2/posts',
              [1, 2, 3].map { |id| { 'id' => id, 'title' => { 'rendered' => "Entrada #{id}" }, 'categories' => [] } },
              headers: { 'X-WP-TotalPages' => '1' })

      catalogo(source)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.map { |i| [i['id'], i['selected']] }).to eq([[1, true], [2, false], [3, true]])
    end

    it 'rechaza una fuente que no es de WordPress' do
      otra = KnowledgeSource.create!(account: account, source_type: 'discourse', name: 'Foro', status: 'active')

      catalogo(otra)

      expect(response).to have_http_status(:bad_request)
    end

    it 'no deja ver una fuente de otra cuenta' do
      ajena = KnowledgeSource.create!(account: create(:account), source_type: 'wordpress',
                                      name: 'Ajeno', status: 'active', config: { 'site_url' => site })

      catalogo(ajena)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST sources/:id/sync' do
    def sincronizar(source)
      post "/api/v1/accounts/#{account.id}/knowledge_base/sources/#{source.id}/sync",
           headers: admin.create_new_auth_token, as: :json
    end

    it 'encola el sincronizador' do
      create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                                 settings: { 'api_key' => 'sk-test' })
      source = source_with('content_types' => ['posts'])

      expect { sincronizar(source) }
        .to have_enqueued_job(WordpressSyncJob)
        .with(action: 'upsert', source_id: source.id, account_id: account.id)
      expect(response).to have_http_status(:success)
    end

    # Sin OpenAI no hay embeddings, así que encolar el job sería dejarlo fallar
    # en Sidekiq donde nadie lo mira.
    it 'no encola nada si la cuenta no tiene integración de OpenAI' do
      source = source_with('content_types' => ['posts'])

      expect { sincronizar(source) }.not_to have_enqueued_job(WordpressSyncJob)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST sources — crear la fuente' do
    it 'guarda la configuración de selección tal como llega' do
      post "/api/v1/accounts/#{account.id}/knowledge_base/sources",
           params: { knowledge_source: { name: 'Blog', source_type: 'wordpress', status: 'active',
                                         config: { site_url: site, content_types: ['posts'],
                                                   categories: [3], excluded_ids: [412] } } },
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      source = account.knowledge_sources.find_by(source_type: 'wordpress')
      expect(source.config).to include('site_url' => site, 'categories' => [3], 'excluded_ids' => [412])
    end
  end
end
