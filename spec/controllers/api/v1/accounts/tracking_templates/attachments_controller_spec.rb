# frozen_string_literal: true

require 'rails_helper'

# proyecto@ai_agent_attachments
RSpec.describe 'Api::V1::Accounts::TrackingTemplates::AttachmentsController', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:tracking_template) { create(:tracking_template, account: account) }
  let(:file) { fixture_file_upload(Rails.root.join('spec/assets/sample.pdf'), 'application/pdf') }
  let(:base_url) { "/api/v1/accounts/#{account.id}/tracking_templates/#{tracking_template.id}/attachments" }

  describe 'GET index' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get base_url
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'lists the agent attachments' do
        create(:ai_agent_attachment, tracking_template: tracking_template, account: account, name: 'catalogo')
        get base_url, headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.first['name']).to eq('catalogo')
      end
    end
  end

  describe 'POST create' do
    it 'creates an attachment' do
      expect do
        post base_url, params: { name: 'catalogo_2026', file: file }, headers: admin.create_new_auth_token
      end.to change(AiAgentAttachment, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['name']).to eq('catalogo_2026')
      expect(response.parsed_body['filename']).to eq('sample.pdf')
    end

    it 'rejects an invalid (non-slug) name' do
      post base_url, params: { name: 'con espacio', file: file }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a missing file' do
      post base_url, params: { name: 'sin_archivo' }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a duplicate name within the same agent' do
      create(:ai_agent_attachment, tracking_template: tracking_template, account: account, name: 'dup')
      post base_url, params: { name: 'dup', file: file }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH update' do
    it 'renames the attachment' do
      attachment = create(:ai_agent_attachment, tracking_template: tracking_template, account: account, name: 'old')
      patch "#{base_url}/#{attachment.id}", params: { name: 'new_name' }, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(attachment.reload.name).to eq('new_name')
    end
  end

  describe 'DELETE destroy' do
    it 'removes the attachment' do
      attachment = create(:ai_agent_attachment, tracking_template: tracking_template, account: account, name: 'kill')
      expect do
        delete "#{base_url}/#{attachment.id}", headers: admin.create_new_auth_token
      end.to change(AiAgentAttachment, :count).by(-1)

      expect(response).to have_http_status(:success)
    end
  end
end
