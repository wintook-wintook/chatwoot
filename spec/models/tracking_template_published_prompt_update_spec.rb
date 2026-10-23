# frozen_string_literal: true

require 'rails_helper'

# proyecto@publicar_prompts (F7): avisar a la copia cuando el autor publica una versión nueva.
RSpec.describe TrackingTemplate, '#published_prompt_update', type: :request do
  let(:author_account) { create(:account) }
  let(:author) { create(:user, account: author_account, role: :administrator) }
  let(:source) { create(:tracking_template, account: author_account, complementary_prompt: 'Versión 1') }
  let(:publisher) { PublishedPrompts::Publisher.new(source, author) }
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let!(:copy) do
    pub = publisher.publish!
    PublishedPrompts::Installer.new(pub, account, admin).install!
  end

  it 'remembers the installed version and has nothing to report' do
    expect(copy.published_prompt_version).to eq(1)
    expect(copy.published_prompt_update).to be_nil
  end

  it 'reports a newer published version until it is seen' do
    source.update!(complementary_prompt: 'Versión 2')
    publisher.publish!

    expect(copy.reload.published_prompt_update).to include('version' => 2, 'current_version' => 1)

    post "/api/v1/accounts/#{account.id}/contact_trackings/assistant/published_prompts/#{copy.published_prompt_id}/seen",
         params: { template_id: copy.id }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(copy.reload.published_prompt_update).to be_nil
    expect(copy.complementary_prompt).to eq('Versión 1')
  end

  it 'stays quiet when the author unpublishes' do
    publisher.publish!
    publisher.unpublish!

    expect(copy.reload.published_prompt_update).to be_nil
  end
end
