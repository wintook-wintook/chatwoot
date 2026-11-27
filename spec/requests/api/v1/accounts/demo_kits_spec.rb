# frozen_string_literal: true

require 'rails_helper'

# Ajustes › Demostraciones — solo administradores; la demo incluida se ve, se importa y se quita.
RSpec.describe 'Demo kits API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/demo_kits" }

  it 'solo administradores' do
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'importa la demo «Estética Bella Luz» con quien se eligió y la quita' do
    get url, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['kits'].pluck('key')).to include('estetica')

    post "#{url}/preview", params: { kit: 'estetica' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('items' => 16)

    post "#{url}/import", params: { kit: 'estetica', people: { p1: admin.id, p2: admin.id }, inboxes: { i1: 'new' } },
                          headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    created = DemoImport.where(account: account).last
    expect(created.ids(:catalog_item_ids).size).to eq(16)
    expect(account.tracking_templates.find(created.ids(:tracking_template_ids).first).motor2.dig('answers', 'user_id')).to eq(admin.id)

    delete "#{url}/#{created.id}", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(account.catalog_items.count).to eq(0)
  end

  it 'un archivo que no es un kit no se importa' do
    post "#{url}/preview", params: { data: { hola: 1 } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
