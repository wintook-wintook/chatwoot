# frozen_string_literal: true

require 'rails_helper'

# proyecto@publicar_prompts (F2)
RSpec.describe 'Api::V1::Accounts::TrackingTemplates::PublicationsController', type: :request do
  let(:account) { create(:account) }
  let(:publisher) { create(:user, account: account, role: :administrator, custom_attributes: { 'can_publish_prompts' => true }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:tracking_template) do
    create(:tracking_template, account: account, name: 'Grúas', complementary_prompt: 'Cotiza con {{hoja:precios}}')
  end
  let(:base_url) { "/api/v1/accounts/#{account.id}/tracking_templates/#{tracking_template.id}/publication" }

  context 'when the user is not allowed to publish' do
    it 'returns forbidden even for an administrator' do
      post base_url, params: { publication: { title: 'X' } }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(PublishedPrompt.count).to eq(0)
    end
  end

  describe 'GET show' do
    it 'returns no publication and what would be published' do
      get base_url, headers: publisher.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['publication']).to be_nil
      expect(response.parsed_body.dig('preview', 'requirements')).to eq([{ 'kind' => 'google_sheet', 'name' => 'precios' }])
    end
  end

  describe 'POST create' do
    it 'publishes and bumps the version when publishing again' do
      post base_url, params: { publication: { title: 'Agente de grúas', category: 'ventas' } },
                     headers: publisher.create_new_auth_token, as: :json
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['publication']).to include('title' => 'Agente de grúas', 'version' => 1, 'status' => 'published')

      post base_url, headers: publisher.create_new_auth_token, as: :json
      expect(response.parsed_body['publication']).to include('title' => 'Agente de grúas', 'version' => 2)
      expect(PublishedPrompt.count).to eq(1)
    end

    it 'rejects an unknown category' do
      post base_url, params: { publication: { category: 'inventada' } }, headers: publisher.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE destroy' do
    it 'unpublishes without deleting the publication' do
      PublishedPrompts::Publisher.new(tracking_template, publisher).publish!

      delete base_url, headers: publisher.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(PublishedPrompt.last.status).to eq('unpublished')
    end
  end
end
