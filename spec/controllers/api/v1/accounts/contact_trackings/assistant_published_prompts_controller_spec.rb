# frozen_string_literal: true

require 'rails_helper'

# proyecto@publicar_prompts (F4)
RSpec.describe 'Api::V1::Accounts::ContactTrackings::AssistantPublishedPromptsController', type: :request do
  let(:author_account) { create(:account, name: 'Grúas SSUSA') }
  let(:author) { create(:user, account: author_account, role: :administrator) }
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/published_prompts" }
  let!(:publication) do
    template = create(:tracking_template, account: author_account, complementary_prompt: 'Cotiza con {{hoja:precios}}')
    PublishedPrompts::Publisher.new(template, author).publish!(title: 'Agente de grúas', category: 'ventas')
  end

  it 'rejects users that are not administrators' do
    get base_url, headers: agent.create_new_auth_token

    expect(response).to have_http_status(:unauthorized)
  end

  describe 'GET index' do
    it 'lists publications from other accounts without the prompt text' do
      get base_url, headers: admin.create_new_auth_token

      item = response.parsed_body['published_prompts'].first
      expect(item).to include('title' => 'Agente de grúas', 'author' => 'Grúas SSUSA', 'own' => false)
      expect(item).not_to have_key('prompt')
    end

    it 'filters by category and hides unpublished ones' do
      get base_url, params: { category: 'cobranza' }, headers: admin.create_new_auth_token
      expect(response.parsed_body['published_prompts']).to be_empty

      publication.update!(status: 'unpublished')
      get base_url, headers: admin.create_new_auth_token
      expect(response.parsed_body['published_prompts']).to be_empty
    end
  end

  describe 'GET show' do
    it 'returns the full prompt' do
      get "#{base_url}/#{publication.id}", headers: admin.create_new_auth_token

      expect(response.parsed_body).to include('prompt' => 'Cotiza con {{hoja:precios}}')
    end

    it 'returns not found for an unpublished one' do
      publication.update!(status: 'unpublished')
      get "#{base_url}/#{publication.id}", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end
  end
end
