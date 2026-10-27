# frozen_string_literal: true

require 'rails_helper'

# prospeccion V4 — la baja desde el enlace del correo (sin usuario).
RSpec.describe 'Public opt-out', type: :request do
  let(:account) { create(:account, name: 'Wintook') }
  let(:contact) { create(:contact, account: account) }
  let(:token) { ContactTrackings::OptOut.token(contact) }

  it 'GET muestra la confirmación y abrir el enlace NO da de baja' do
    get "/baja/#{token}"

    expect(response).to have_http_status(:success)
    expect(response.body).to include('Wintook')
    expect(contact.reload).not_to be_opted_out
  end

  it 'POST da de baja y muestra que ya no le escribiremos' do
    post "/baja/#{token}"

    expect(response).to have_http_status(:success)
    expect(contact.reload).to be_opted_out
    expect(contact.opted_out_source).to eq('link')
  end

  it 'la baja con un clic de Gmail responde 200 sin página' do
    post "/baja/#{token}", params: { 'List-Unsubscribe' => 'One-Click' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to be_empty
    expect(contact.reload).to be_opted_out
  end

  it 'un token alterado da 404' do
    get "/baja/#{token}x"

    expect(response).to have_http_status(:not_found)
  end
end
