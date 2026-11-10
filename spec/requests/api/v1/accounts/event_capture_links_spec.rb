# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event capture links API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel) do
    create(:channel_whatsapp, account: account, phone_number: '+5215512345678', sync_templates: false, validate_provider_config: false)
  end
  let(:event) { Event.create!(account: account, name: 'Expo Industrial 2026', starts_at: Time.current) }
  let(:base) { "/api/v1/accounts/#{account.id}/events/#{event.id}/capture_links" }

  it 'crea, lista y borra los enlaces del evento' do
    post base, params: { inbox_id: channel.inbox.id, user_id: admin.id, message: 'Hola, los conocí en la Expo' },
               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    created = response.parsed_body['link']
    expect(created).to include('url' => start_with('https://wa.me/5215512345678'), 'user' => include('id' => admin.id))

    get base, headers: admin.create_new_auth_token, as: :json
    body = response.parsed_body
    expect(body['links'].pluck('id')).to eq([created['id']])
    expect(body['inboxes'].pluck('id')).to eq([channel.inbox.id])
    expect(body['default_message']).to include('Expo Industrial 2026')

    delete "#{base}/#{created['id']}", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:no_content)
    expect(event.capture_links.count).to eq(0)
  end

  it 'rechaza una bandeja que no es de WhatsApp' do
    post base, params: { inbox_id: create(:inbox, account: account).id, message: 'x' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
