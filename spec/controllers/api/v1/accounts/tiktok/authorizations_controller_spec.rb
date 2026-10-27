require 'rails_helper'

# Portado de Chatwoot 4.19. Diferencia nuestra: con el canal apagado respondemos 422 con un
# mensaje (allá es 401), para que el dashboard pueda explicar por qué no se puede conectar.
RSpec.describe 'TikTok Authorization API', type: :request do
  let(:account) { create(:account) }

  describe 'POST /api/v1/accounts/{account.id}/tiktok/authorization' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/tiktok/authorization"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      before do
        InstallationConfig.where(name: %w[TIKTOK_APP_ID TIKTOK_APP_SECRET]).delete_all
        GlobalConfig.clear_cache
      end

      it 'returns unauthorized for agent' do
        account.enable_features!('channel_tiktok')

        with_modified_env TIKTOK_APP_ID: 'tiktok-app-id', TIKTOK_APP_SECRET: 'tiktok-app-secret' do
          post "/api/v1/accounts/#{account.id}/tiktok/authorization",
               headers: agent.create_new_auth_token,
               as: :json
        end

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects the request when TikTok is disabled for the account' do
        account.disable_features!('channel_tiktok')

        with_modified_env TIKTOK_APP_ID: 'tiktok-app-id', TIKTOK_APP_SECRET: 'tiktok-app-secret' do
          post "/api/v1/accounts/#{account.id}/tiktok/authorization",
               headers: administrator.create_new_auth_token,
               as: :json
        end

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['success']).to be false
      end

      it 'creates a new authorization and returns the redirect url' do
        account.enable_features!('channel_tiktok')

        travel_to Time.zone.parse('2025-01-01 00:00:00 UTC') do
          with_modified_env TIKTOK_APP_ID: 'tiktok-app-id', TIKTOK_APP_SECRET: 'tiktok-app-secret' do
            post "/api/v1/accounts/#{account.id}/tiktok/authorization",
                 headers: administrator.create_new_auth_token,
                 as: :json

            expect(response).to have_http_status(:success)
            expect(response.parsed_body['success']).to be true

            helper = Class.new { include Tiktok::IntegrationHelper }.new
            expected_url = Tiktok::AuthClient.authorize_url(state: helper.generate_tiktok_token(account.id))

            expect(response.parsed_body['url']).to eq(expected_url)
          end
        end
      end
    end
  end
end
