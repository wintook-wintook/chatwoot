# frozen_string_literal: true

require 'rails_helper'

# proyecto@respuestas_predefinidas R2
RSpec.describe 'Canned Responses API — tabla', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/canned_responses" }

  before { %w[UNO DOS TRES].each { |n| create(:canned_response, account: account, short_code: n) } }

  it 'con page regresa la página y el total; sin page, la lista de siempre' do
    get url, params: { page: 1, per_page: 2, sort: 'short_code' }, headers: agent.create_new_auth_token

    expect(response.parsed_body['meta']).to eq('count' => 3, 'page' => 1, 'per_page' => 2,
                                               'summary' => { 'no_key' => 0, 'missing' => 0, 'failed' => 0 })
    expect(response.parsed_body['payload'].pluck('short_code')).to eq(%w[DOS TRES])

    get url, headers: agent.create_new_auth_token
    expect(response.parsed_body.size).to eq(3)
  end

  it 'elimina varias a la vez, solo de la cuenta' do
    ids = account.canned_responses.where(short_code: %w[UNO DOS]).pluck(:id)
    ajena = create(:canned_response, account: create(:account))

    post "#{url}/destroy_many", params: { ids: ids + [ajena.id] }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(account.canned_responses.pluck(:short_code)).to eq(%w[TRES])
    expect(CannedResponse.exists?(ajena.id)).to be(true)
  end

  # proyecto@predefinidas_que_contestan: la categoría es fija (campo kind).
  it 'filtra por categoría fija y la cambia en varias, solo de la cuenta' do
    ficha = create(:canned_response, account: account, short_code: 'Plan X', kind: 'ficha')
    general = create(:canned_response, account: account, short_code: 'Horario')
    ajena = create(:canned_response, short_code: 'Ajena')

    get url, params: { page: 1, kind: 'ficha' }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['payload'].pluck('short_code')).to eq(['Plan X'])

    post "#{url}/assign_kind", params: { ids: [general.id, ajena.id], kind: 'objecion' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(general.reload.kind).to eq('objecion')
    expect(ajena.reload.kind).to eq('general')
    expect(ficha.reload.kind).to eq('ficha')

    post "#{url}/assign_kind", params: { ids: [general.id], kind: 'proceso' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
