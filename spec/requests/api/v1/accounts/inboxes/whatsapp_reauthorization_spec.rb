# frozen_string_literal: true

require 'rails_helper'

# diag/waba F3 (H4) — la bandeja de WhatsApp manda a la pantalla si requiere reconexión.
RSpec.describe 'Inbox JSON · WhatsApp requiere reconexión' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end

  def inbox_json
    get "/api/v1/accounts/#{account.id}/inboxes/#{channel.inbox.id}", headers: admin.create_new_auth_token, as: :json
    response.parsed_body
  end

  it 'false mientras el permiso de Meta sirve; true tras dos errores de autorización' do
    expect(inbox_json['reauthorization_required']).to be(false)

    2.times { channel.authorization_error! }
    expect(inbox_json['reauthorization_required']).to be(true)
  end
end
