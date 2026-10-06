# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Knowledge Base API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'POST /api/v1/accounts/{account.id}/knowledge_base/directive' do
    let(:params) { { directive: '@buscar_predefinidas', query: 'necesito actualizar mis datos fiscales' } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/knowledge_base/directive", params: params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      def post_directive(overrides = {})
        post "/api/v1/accounts/#{account.id}/knowledge_base/directive",
             params: params.merge(overrides),
             headers: agent.create_new_auth_token,
             as: :json
      end

      it 'returns 422 when directive is not exactly @buscar_predefinidas' do
        post_directive(directive: '@buscar_predefinidas(GESTION)')

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns 400 when query is missing' do
        post_directive(query: '')

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns 422 when the account has no OpenAI integration' do
        post_directive

        expect(response).to have_http_status(:unprocessable_entity)
      end

      context 'with an OpenAI integration configured' do
        before { create(:integrations_hook, :openai, account: account) }

        it 'returns resolved: false with reason: no_match when nothing beats the threshold' do
          allow(KnowledgeItem).to receive(:search_by_embedding).and_return([])
          stub_request(:post, 'https://api.openai.com/v1/embeddings')
            .to_return(status: 200, body: { data: [{ embedding: [0.1, 0.2] }] }.to_json, headers: { 'Content-Type' => 'application/json' })

          post_directive

          expect(response).to have_http_status(:success)
          body = response.parsed_body
          expect(body['resolved']).to be false
          expect(body['reason']).to eq('no_match')
          expect(body['directive']).to eq('@buscar_predefinidas')
          expect(body['mode']).to eq('canned_response')
        end
      end
    end
  end
end
