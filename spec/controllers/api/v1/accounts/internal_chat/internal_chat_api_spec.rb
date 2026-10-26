require 'rails_helper'

# feat/chat_interno (F0–F2) — API del chat interno: permisos, salas, mensajes, no leídos,
# miembros y tiempo real. Plan: docs/chat_interno_plan.md
RSpec.describe 'Internal chat API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:ana) { create(:user, account: account, role: :agent) }
  let(:luis) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user) }
  let(:base) { "/api/v1/accounts/#{account.id}/internal_chat/rooms" }

  def get_json(path, user)
    get path, headers: user.create_new_auth_token, as: :json
  end

  def post_json(path, user, params = {})
    post path, params: params, headers: user.create_new_auth_token, as: :json
  end

  def direct_between(first, second)
    InternalChat::Rooms.new(account: account, user: first).direct!(second.id)
  end

  describe 'gate' do
    it 'returns 404 when the chat is turned off for the account' do
      account.update!(internal_chat_enabled: false)
      get_json(base, ana)
      expect(response).to have_http_status(:not_found)
    end

    it 'rejects users from another account' do
      get_json(base, outsider)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET rooms' do
    it 'creates the general room once and starts it as read', :aggregate_failures do
      general = InternalChatRoom.general_for(account)
      general.messages.create!(user: luis, content: 'mensaje viejo')

      get_json(base, ana)
      get_json(base, ana)

      rooms = response.parsed_body['payload']
      expect(InternalChatRoom.where(account: account, kind: 'general').count).to eq(1)
      expect(rooms.first['kind']).to eq('general')
      expect(rooms.first['unread_count']).to eq(0)
      expect(rooms.first['member_ids']).to include(ana.id, luis.id)
    end

    it 'counts only messages from others after the last read', :aggregate_failures do
      room = direct_between(ana, luis)
      room.messages.create!(user: luis, content: 'hola')
      room.messages.create!(user: luis, content: '¿estás?')
      room.messages.create!(user: ana, content: 'mío')

      get_json(base, ana)
      direct = response.parsed_body['payload'].find { |item| item['id'] == room.id }
      expect(direct['unread_count']).to eq(2)
      expect(direct['last_message']['content']).to eq('mío')

      post_json("#{base}/#{room.id}/read", ana)
      get_json(base, ana)
      expect(response.parsed_body['payload'].find { |item| item['id'] == room.id }['unread_count']).to eq(0)
    end

    it 'does not list rooms the agent is not in' do
      room = direct_between(luis, admin)
      get_json(base, ana)
      expect(response.parsed_body['payload'].pluck('id')).not_to include(room.id)
    end
  end

  describe 'POST rooms' do
    it 'opens a direct only once between two agents' do
      post_json(base, ana, user_id: luis.id)
      first = response.parsed_body['id']
      post_json(base, luis, user_id: ana.id)
      expect(response.parsed_body['id']).to eq(first)
      expect(InternalChatRoom.where(kind: 'direct').count).to eq(1)
    end

    it 'refuses a direct with yourself or with someone outside the account' do
      post_json(base, ana, user_id: ana.id)
      expect(response).to have_http_status(:unprocessable_entity)
      post_json(base, ana, user_id: outsider.id)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'privacy' do
    it 'does not let an administrator read a direct between two other agents' do
      room = direct_between(ana, luis)
      get_json("#{base}/#{room.id}/messages", admin)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'messages' do
    let(:room) { direct_between(ana, luis) }

    it 'sends a message, marks it read for the sender and broadcasts to members only', :aggregate_failures do
      room # la sala ya existe: su aviso de creación no entra en la expectativa
      expect(ActionCableBroadcastJob).to receive(:perform_later) do |tokens, event, data|
        expect(tokens).to contain_exactly(ana.pubsub_token, luis.pubsub_token)
        expect(event).to eq('internal_chat.message.created')
        expect(data[:message][:content]).to eq('¿lo tomas tú?')
        expect(data[:account_id]).to eq(account.id)
      end

      post_json("#{base}/#{room.id}/messages", ana, content: '  ¿lo tomas tú?  ')

      expect(response).to have_http_status(:created)
      expect(room.reload.last_message_at).to be_present
      expect(InternalChat::RoomList.unread_count_for(room, ana)).to eq(0)
      expect(InternalChat::RoomList.unread_count_for(room, luis)).to eq(1)
    end

    it 'rejects empty messages' do
      post_json("#{base}/#{room.id}/messages", ana, content: '   ')
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'pages back with before', :aggregate_failures do
      55.times { |i| room.messages.create!(user: ana, content: "m#{i}") }
      get_json("#{base}/#{room.id}/messages", luis)
      body = response.parsed_body
      expect(body['payload'].size).to eq(50)
      expect(body['payload'].last['content']).to eq('m54')
      expect(body['meta']['has_more']).to be true

      get_json("#{base}/#{room.id}/messages?before=#{body['payload'].first['id']}", luis)
      expect(response.parsed_body['payload'].pluck('content')).to eq(%w[m0 m1 m2 m3 m4])
    end
  end

  describe 'team rooms' do
    let!(:team) { create(:team, account: account, name: 'ventas') }

    before do
      team.add_member(ana.id)
      team.add_member(luis.id)
    end

    def team_room
      InternalChatRoom.find_by!(account: account, team: team)
    end

    it 'creates one room per team, named like the team, only for its members', :aggregate_failures do
      get_json(base, ana)
      get_json(base, luis)
      expect(InternalChatRoom.where(account: account, kind: 'team').count).to eq(1)
      room = response.parsed_body['payload'].find { |item| item['kind'] == 'team' }
      expect(room['name']).to eq('ventas')
      expect(room['member_ids']).to contain_exactly(ana.id, luis.id)

      get_json(base, admin)
      expect(response.parsed_body['payload'].pluck('kind')).not_to include('team')
    end

    it 'keeps people outside the team out of its room' do
      get_json(base, ana)
      get_json("#{base}/#{team_room.id}/messages", admin)
      expect(response).to have_http_status(:not_found)
    end

    it 'sends team messages only to the team members' do
      get_json(base, ana)
      expect(ActionCableBroadcastJob).to receive(:perform_later) do |tokens, event, _data|
        expect(event).to eq('internal_chat.message.created')
        expect(tokens).to contain_exactly(ana.pubsub_token, luis.pubsub_token)
      end
      post_json("#{base}/#{team_room.id}/messages", ana, content: '¿quién cubre hoy?')
      expect(response).to have_http_status(:created)
    end

    it 'follows the team: a removed member loses access and deleting the team deletes the room', :aggregate_failures do
      get_json(base, ana)
      room = team_room
      team.remove_member(luis.id)
      expect(room.accessible_by?(luis)).to be false
      team.destroy!
      expect(InternalChatRoom.exists?(room.id)).to be false
    end
  end

  describe 'account membership' do
    it 'removes an agent from every room of the account when they leave it' do
      room = direct_between(ana, luis)
      account.account_users.find_by(user: luis).destroy!
      expect(room.reload.members.pluck(:user_id)).to eq([ana.id])
    end
  end

  describe 'toggle' do
    it 'is on by default and only stores the exception', :aggregate_failures do
      expect(account.internal_chat_enabled?).to be true
      account.update!(internal_chat_enabled: '0')
      expect(account.reload.custom_attributes['internal_chat_disabled']).to be true
      account.update!(internal_chat_enabled: '1')
      expect(account.reload.custom_attributes).not_to have_key('internal_chat_disabled')
    end
  end
end
