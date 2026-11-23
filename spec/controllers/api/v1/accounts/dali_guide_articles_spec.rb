# frozen_string_literal: true

require 'rails_helper'

# Artículos del portal «Guías de Dali»: editarlos desde la pantalla no debe borrar lo que
# Dali usa (guide_key, areas, keywords, pages, sources) — paso 3 de docs/dali_guias_centro_ayuda_plan.md.
RSpec.describe 'Api::V1::Accounts::Articles (Guías de Dali)', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:slug) { "ayuda-dali-spec-#{SecureRandom.hex(3)}" }
  let!(:portal) { create(:portal, slug: slug, account_id: account.id) }
  let(:guide_meta) do
    { 'guide_key' => 'agenda', 'areas' => %w[agenda], 'keywords' => %w[agenda tarea cita], 'tags' => %w[agenda],
      'pages' => %w[agenda], 'sources' => ['app/models/agenda*.rb'], 'reviewed' => '2026-11-14' }
  end
  let!(:article) do
    create(:article, portal: portal, account_id: account.id, author_id: admin.id, slug: "kontrolya-agenda-#{SecureRandom.hex(3)}",
                     meta: guide_meta)
  end

  around { |example| ClimateControl.modify(PLATFORM_HELP_PORTAL_SLUG: slug) { example.run } }

  def update(article_params)
    put "/api/v1/accounts/#{account.id}/portals/#{portal.slug}/articles/#{article.id}",
        params: { article: article_params }, headers: admin.create_new_auth_token, as: :json
  end

  it 'conserva la cabecera de la guía al guardar las meta etiquetas desde la pantalla' do
    update(meta: { title: 'Agenda', description: 'Cómo usar la agenda', tags: %w[nueva] })

    expect(response).to have_http_status(:success)
    expect(article.reload.meta).to eq(guide_meta.merge('title' => 'Agenda', 'description' => 'Cómo usar la agenda',
                                                       'tags' => %w[nueva]))
  end

  it 'cambia áreas, palabras clave, pantallas y revisión, pero no la clave ni sources' do
    update(meta: { areas: %w[sales], keywords: %w[venta], pages: %w[case], reviewed: '2026-11-23',
                   guide_key: 'otra', sources: ['x.rb'] })

    expect(response).to have_http_status(:success)
    expect(article.reload.meta).to include('areas' => %w[sales], 'keywords' => %w[venta], 'pages' => %w[case],
                                           'reviewed' => '2026-11-23', 'guide_key' => 'agenda',
                                           'sources' => ['app/models/agenda*.rb'])
  end

  it 'deja vaciar las áreas (la ve todo el mundo)' do
    update(meta: { areas: [] })

    expect(article.reload.meta['areas']).to eq([])
  end

  it 'rechaza áreas y pantallas que no existen' do
    update(meta: { areas: %w[inventada], pages: %w[no_existe] })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(article.reload.meta).to eq(guide_meta)
  end

  it 'regresa la clave de la guía en el artículo y las opciones en el portal' do
    get "/api/v1/accounts/#{account.id}/portals/#{portal.slug}/articles/#{article.id}", headers: admin.create_new_auth_token

    expect(response.parsed_body['payload']['dali_guide']).to eq('key' => 'agenda')

    get "/api/v1/accounts/#{account.id}/portals/#{portal.slug}", headers: admin.create_new_auth_token
    options = response.parsed_body['dali_guides']
    expect(options['areas']).to eq(AccessRole::AREAS)
    expect(options['pages']).to include({ 'key' => 'case', 'label' => 'Un caso (por su número)' })
  end

  it 'a un artículo nuevo le pone slug «kontrolya-…» y su clave' do
    post "/api/v1/accounts/#{account.id}/portals/#{portal.slug}/articles",
         params: { article: { title: 'Cómo cobrar una factura', content: 'Texto', author_id: admin.id } },
         headers: admin.create_new_auth_token, as: :json

    created = portal.articles.find(response.parsed_body['payload']['id'])
    expect(created.slug).to eq('kontrolya-como-cobrar-una-factura')
    expect(created.dali_guide_key).to eq('como_cobrar_una_factura')
  end

  context 'when el portal no es el de Dali' do
    let(:other_portal) { create(:portal, account_id: account.id) }
    let(:other_article) do
      create(:article, portal: other_portal, account_id: account.id, author_id: admin.id, meta: { 'title' => 'x', 'extra' => 'y' })
    end

    it 'combina el meta igual, pero no acepta los campos de Dali ni muestra la guía' do
      put "/api/v1/accounts/#{account.id}/portals/#{other_portal.slug}/articles/#{other_article.id}",
          params: { article: { meta: { title: 'Nuevo', areas: %w[sales] } } }, headers: admin.create_new_auth_token, as: :json

      expect(other_article.reload.meta).to eq('title' => 'Nuevo', 'extra' => 'y')
      expect(response.parsed_body['payload']).not_to have_key('dali_guide')
    end
  end
end
