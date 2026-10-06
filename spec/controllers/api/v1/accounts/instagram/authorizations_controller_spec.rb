require 'rails_helper'

RSpec.describe 'Instagram Authorization API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  describe 'POST /api/v1/accounts/{account.id}/instagram/authorization' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/instagram/authorization"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the channel_instagram feature is disabled' do
      it 'refuses to start the flow' do
        post "/api/v1/accounts/#{account.id}/instagram/authorization",
             headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['success']).to be(false)
      end
    end

    context 'when the channel_instagram feature is enabled' do
      before { account.enable_features!('channel_instagram') }

      it 'returns unauthorized for an agent' do
        post "/api/v1/accounts/#{account.id}/instagram/authorization",
             headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns the instagram authorize url and remembers the account under the state' do
        post "/api/v1/accounts/#{account.id}/instagram/authorization",
             headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)

        url = response.parsed_body['url']
        expect(url).to start_with('https://www.instagram.com/oauth/authorize?')

        state = CGI.parse(URI.parse(url).query)['state'].first
        expect(state).to be_present
        expect(Redis::Alfred.get(format(Redis::Alfred::IG_OAUTH_STATE, state: state))).to eq(account.id.to_s)
      end

      # Sin enable_fb_login=0 Meta puede resolver por Facebook Login y devolver un token
      # de Página, que no sirve contra graph.instagram.com.
      it 'forces the instagram login path and a fresh account choice' do
        post "/api/v1/accounts/#{account.id}/instagram/authorization",
             headers: administrator.create_new_auth_token, as: :json

        query = CGI.parse(URI.parse(response.parsed_body['url']).query)

        expect(query['enable_fb_login'].first).to eq('0')
        expect(query['force_authentication'].first).to eq('1')
        expect(query['scope'].first).to eq('instagram_business_basic,instagram_business_manage_messages')
      end

      it 'does not reuse the same state across requests' do
        states = Array.new(2) do
          post "/api/v1/accounts/#{account.id}/instagram/authorization",
               headers: administrator.create_new_auth_token, as: :json
          CGI.parse(URI.parse(response.parsed_body['url']).query)['state'].first
        end

        expect(states.uniq.size).to eq(2)
      end
    end
  end
end
