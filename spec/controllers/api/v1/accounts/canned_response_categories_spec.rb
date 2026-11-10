# frozen_string_literal: true

require 'rails_helper'

# proyecto@respuestas_predefinidas R3 — API de categorías y asignación en lote.
RSpec.describe 'Canned Response Categories API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/canned_response_categories" }
  let!(:uno) { create(:canned_response, account: account, short_code: 'PATITAS UNO') }
  let!(:dos) { create(:canned_response, account: account, short_code: 'PATITAS DOS') }

  it 'crear una categoría con sus predefinidas (aceptar una sugerencia) y listarla con su cuenta' do
    post url, params: { canned_response_category: { name: 'PATITAS' }, canned_ids: [uno.id, dos.id] },
              headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('name' => 'PATITAS', 'canned_count' => 2)

    get url, headers: agent.create_new_auth_token
    expect(response.parsed_body.map { |c| [c['name'], c['canned_count']] }).to eq([['PATITAS', 2]])

    get "#{url}/suggestions", headers: agent.create_new_auth_token
    expect(response.parsed_body).to eq([])
  end

  it 'renombrar, y borrar deja las predefinidas sin categoría' do
    categoria = CannedResponseCategory.create!(account: account, name: 'VET')
    uno.update!(category: categoria)

    patch "#{url}/#{categoria.id}", params: { canned_response_category: { name: 'VETERINARIA' } },
                                    headers: agent.create_new_auth_token, as: :json
    expect(categoria.reload.name).to eq('VETERINARIA')

    delete "#{url}/#{categoria.id}", headers: agent.create_new_auth_token
    expect(uno.reload.category_id).to be_nil
  end

  it 'cambiar la categoría de varias desde la tabla, y quitarla' do
    categoria = CannedResponseCategory.create!(account: account, name: 'VET')
    asignar = "/api/v1/accounts/#{account.id}/canned_responses/assign_category"

    post asignar, params: { ids: [uno.id, dos.id], category_id: categoria.id }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.pluck('category_name')).to eq(%w[VET VET])

    post asignar, params: { ids: [uno.id], category_id: nil }, headers: agent.create_new_auth_token, as: :json
    expect(uno.reload.category_id).to be_nil
  end

  it 'la tabla filtra y ordena por categoría' do
    categoria = CannedResponseCategory.create!(account: account, name: 'VET')
    dos.update!(category: categoria)
    tabla = "/api/v1/accounts/#{account.id}/canned_responses"

    get tabla, params: { page: 1, category: categoria.id }, headers: agent.create_new_auth_token
    expect(response.parsed_body['payload'].pluck('short_code')).to eq(['PATITAS DOS'])
    get tabla, params: { page: 1, category: 'none' }, headers: agent.create_new_auth_token
    expect(response.parsed_body['payload'].pluck('short_code')).to eq(['PATITAS UNO'])
    get tabla, params: { page: 1, sort: 'category' }, headers: agent.create_new_auth_token
    expect(response.parsed_body['payload'].pluck('category_name')).to eq(['VET', nil])
  end
end
