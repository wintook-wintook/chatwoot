# frozen_string_literal: true

require 'rails_helper'

# proyecto@respuestas_predefinidas R1
RSpec.describe 'Canned Responses API — vectorizar', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:canned) { create(:canned_response, account: account) }

  it 'la lista dice si cada una está en la fuente de datos' do
    CannedResponse.where(id: canned.id).update_all(embedding_status: nil) # rubocop:disable Rails/SkipsModelValidations
    get "/api/v1/accounts/#{account.id}/canned_responses", headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.first['embedding_state']).to eq('no_key')

    create(:integrations_hook, :openai, account: account)
    get "/api/v1/accounts/#{account.id}/canned_responses", headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.first['embedding_state']).to eq('missing')
  end

  it '[Vectorizar] la encola y la deja en camino' do
    expect do
      post "/api/v1/accounts/#{account.id}/canned_responses/#{canned.id}/vectorize", headers: agent.create_new_auth_token, as: :json
    end.to have_enqueued_job(KnowledgeItemSyncJob).with(hash_including(source_id: canned.id))
    expect(response.parsed_body).to include('id' => canned.id, 'embedding_state' => 'pending')
  end

  it 'varias a la vez, hasta 20' do
    otra = create(:canned_response, account: account)
    post "/api/v1/accounts/#{account.id}/canned_responses/vectorize", params: { ids: [canned.id, otra.id] },
                                                                      headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.pluck('id')).to contain_exactly(canned.id, otra.id)

    post "/api/v1/accounts/#{account.id}/canned_responses/vectorize", params: { ids: (1..21).to_a },
                                                                      headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
