require 'rails_helper'

# feat/chat_interno (plan v2, R2) — privacidad y no leídos por agente en «Interno».
RSpec.describe 'Internal channel privacy', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:ana) { create(:user, account: account, role: :agent) }
  let!(:luis) { create(:user, account: account, role: :agent) }
  let!(:inbox) { InternalChannel::Setup.new(account).call }
  let(:direct) { InternalChannel::Direct.new(account: account, user: ana).open!(luis.id) }
  let(:base) { "/api/v1/accounts/#{account.id}/conversations" }

  def say(conversation, user, text)
    conversation.messages.create!(account: account, inbox: inbox, sender: user, message_type: :outgoing, content: text)
  end

  def list_ids(user)
    get base, params: { inbox_id: inbox.id, status: 'all' }, headers: user.create_new_auth_token, as: :json
    response.parsed_body['data']['payload'].pluck('id')
  end

  it 'lists only the internal conversations the agent takes part in', :aggregate_failures do
    direct
    expect(list_ids(ana)).to include(direct.display_id)
    expect(list_ids(admin)).not_to include(direct.display_id)
  end

  it 'does not let anyone outside a direct open it, not even an administrator', :aggregate_failures do
    get "#{base}/#{direct.display_id}", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    get "#{base}/#{direct.display_id}/messages", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    get "#{base}/#{direct.display_id}", headers: luis.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
  end

  it 'counts unread per agent and follows seen / mark unread', :aggregate_failures do
    say(direct, ana, 'hola')
    say(direct, ana, '¿estás?')
    expect(InternalChannel::Access.unread_count(direct, luis)).to eq(2)
    expect(InternalChannel::Access.unread_count(direct, ana)).to eq(0)

    post "#{base}/#{direct.display_id}/update_last_seen", headers: luis.create_new_auth_token, as: :json
    expect(InternalChannel::Access.unread_count(direct, luis)).to eq(0)

    post "#{base}/#{direct.display_id}/unread", headers: luis.create_new_auth_token, as: :json
    expect(InternalChannel::Access.unread_count(direct, luis)).to eq(1)
  end

  it 'hides every internal conversation when the chat is turned off' do
    direct
    account.update!(internal_chat_enabled: false)
    expect(list_ids(ana)).not_to include(direct.display_id)
  end

  it 'keeps internal messages out of the search of agents outside the conversation' do
    say(direct, ana, 'clave-secreta-123')
    get "/api/v1/accounts/#{account.id}/search/messages", params: { q: 'clave-secreta-123' },
                                                          headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('payload', 'messages')).to be_blank
  end

  # «Solo lo suyo» (Plan-Roles-Permisos) filtra por asignado; «Interno» no tiene asignado,
  # así que sin «tomar sin asignar» desaparecería.
  it 'keeps internal conversations for agents who only see their own', :aggregate_failures do
    direct
    seller = AccessRole.for_account(account).find { |r| r.key == 'seller' }
    seller.update!(actions: seller.actions.merge('take_unassigned' => false))
    account.account_users.find_by(user: ana).update!(access_role: seller)

    expect(list_ids(ana)).to include(direct.display_id)
    get "#{base}/#{direct.display_id}", headers: ana.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
  end
end
