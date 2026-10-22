# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F3) — el API de llamadas que usa el dashboard.
RSpec.describe 'Llamadas de WhatsApp — API' do
  let(:channel) { calling_channel }
  let(:account) { channel.account }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:ajeno) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox) }
  let(:call) { create(:call, account: account, inbox: channel.inbox, conversation: conversation, contact: conversation.contact) }
  let(:base) { "/api/v1/accounts/#{account.id}/whatsapp_calls" }

  before do
    stub_meta_calls
    allow(ActionCable.server).to receive(:broadcast)
    create(:inbox_member, inbox: channel.inbox, user: agente)
  end

  it 'un agente que no es de la bandeja no puede' do
    post "#{base}/#{call.id}/accept", params: { sdp_answer: 'v=0' }, headers: ajeno.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'contestar la pone en curso; contestarla otra vez da 409' do
    post "#{base}/#{call.id}/accept", params: { sdp_answer: 'v=0' }, headers: agente.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['status']).to eq('in-progress')

    post "#{base}/#{call.id}/accept", params: { sdp_answer: 'v=0' }, headers: agente.create_new_auth_token, as: :json
    expect(response).to have_http_status(:conflict)
  end

  describe 'llamar' do
    def llamar
      post "#{base}/initiate", params: { conversation_id: conversation.display_id, sdp_offer: 'v=0 offer' },
                               headers: agente.create_new_auth_token, as: :json
    end

    it 'crea la saliente sonando, con su burbuja, y se asigna la conversación' do
      allow_any_instance_of(Whatsapp::Providers::WhatsappCloudService) # rubocop:disable RSpec/AnyInstance
        .to receive(:initiate_call).and_return({ 'calls' => [{ 'id' => 'wacid.out' }] })

      llamar

      expect(response).to have_http_status(:ok)
      nueva = Call.find_by!(provider_call_id: 'wacid.out')
      expect(nueva).to have_attributes(direction: 'outgoing', status: 'ringing', accepted_by_agent: agente)
      expect(nueva.message).to have_attributes(message_type: 'outgoing', content_type: 'voice_call')
      expect(conversation.reload.assignee).to eq(agente)
    end

    it 'sin permiso del cliente pide el permiso y responde 422 permission_requested' do
      allow_any_instance_of(Whatsapp::Providers::WhatsappCloudService) # rubocop:disable RSpec/AnyInstance
        .to receive(:initiate_call).and_raise(Voice::CallErrors::NoCallPermission, 'No permission')
      allow_any_instance_of(Whatsapp::Providers::WhatsappCloudService) # rubocop:disable RSpec/AnyInstance
        .to receive(:send_call_permission_request).and_return({ 'messages' => [{ 'id' => 'wamid.1' }] })

      llamar

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to include('status' => 'permission_requested', 'conversation_id' => conversation.display_id)
      expect(Call.count).to eq(0)
    end

    it 'en una bandeja de solo entrantes no se puede' do
      channel.update_columns(provider_config: channel.provider_config.merge('calling_direction' => 'inbound')) # rubocop:disable Rails/SkipsModelValidations
      llamar
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
