# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — la API de la ficha.
RSpec.describe 'Ficha del Agente IA API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/tracking_templates" }
  let!(:hoja) { create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Precios') }
  let(:items) { [{ key: "google_sheet:#{hoja.id}" }] }

  before do
    GoogleSheetRow.create!(account: account, knowledge_source: hoja, row_index: 0, data: { 'Producto' => 'Grúa', 'Precio' => '1800' })
  end

  it 'solo administradores' do
    get "#{base}/ficha_catalog", headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end

  it 'catálogo → vista previa → crear, en unos cuantos clics' do
    get "#{base}/ficha_catalog", headers: admin.create_new_auth_token
    expect(response.parsed_body['cards'].pluck('key')).to include("google_sheet:#{hoja.id}")

    post "#{base}/ficha_preview", params: { name: 'Ventas', items: items }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['validation']['valid']).to be(true)
    expect(response.parsed_body['offers'].first).to include('key' => "google_sheet:#{hoja.id}", 'on' => true)

    expect do
      post "#{base}/ficha_create", params: { name: 'Ventas', items: items }, headers: admin.create_new_auth_token, as: :json
    end.to change(account.tracking_templates, :count).by(1)
    creado = account.tracking_templates.find(response.parsed_body['id'])
    expect(creado.complementary_prompt).to include('{{hoja_buscar: Precios')
    expect(creado.resources['items']).to eq([{ 'key' => "google_sheet:#{hoja.id}" }])
  end

  it 'guarda la ficha de un agente, dice los cambios y los aplica' do
    template = create(:tracking_template, account: account, complementary_prompt: "@ruta(info #info: pregunta algo): @buscar_articulo\n")

    patch "#{base}/#{template.id}/ficha", params: { items: items }, headers: admin.create_new_auth_token, as: :json
    cambios = response.parsed_body['changes']
    expect(cambios['added'].pluck('key')).to eq(["google_sheet:#{hoja.id}"])

    post "#{base}/#{template.id}/ficha/apply", params: { add: ["google_sheet:#{hoja.id}"] },
                                               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(template.reload.complementary_prompt).to include('{{hoja_buscar: Precios')
    expect(response.parsed_body['changes']['added']).to eq([])
  end
end
