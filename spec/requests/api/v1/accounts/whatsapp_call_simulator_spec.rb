# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F4) — la Meta simulada, de punta a punta en el servidor: el
# cliente simulado llama → webhook con forma de Meta → job real → la llamada suena →
# el agente contesta por la API → la página del cliente recoge el answer → cuelga.
RSpec.describe 'Meta simulada (cliente simulado)' do
  let(:channel) { calling_channel }
  let(:account) { channel.account }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:base) { "/api/v1/accounts/#{account.id}/whatsapp_call_simulator" }
  let(:wa_id) { '5215599990000' }

  def con_simulador(&)
    with_modified_env(WHATSAPP_CALLS_SIMULATOR: 'true', &)
  end

  def senales
    get "#{base}/signals", params: { inbox_id: channel.inbox.id, wa_id: wa_id }, headers: admin.create_new_auth_token
    response.parsed_body
  end

  before { allow(ActionCable.server).to receive(:broadcast) }

  it 'sin el simulador encendido no existe (404)' do
    get "#{base}/inboxes", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)
  end

  it 'solo administradores' do
    agente = create(:user, account: account, role: :agent)
    con_simulador { get "#{base}/inboxes", headers: agente.create_new_auth_token }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'el cliente llama, el agente contesta, el cliente recibe el audio y cuelga' do
    con_simulador do
      get "#{base}/inboxes", headers: admin.create_new_auth_token
      expect(response.parsed_body.pluck('id')).to eq([channel.inbox.id])

      perform_enqueued_jobs(only: Webhooks::WhatsappCallEventsJob) do
        post "#{base}/call", params: { inbox_id: channel.inbox.id, wa_id: wa_id, name: 'Cliente de prueba', sdp_offer: 'v=0 offer' },
                             headers: admin.create_new_auth_token, as: :json
      end
      call = Call.find_by!(provider_call_id: response.parsed_body['call_id'])
      expect(call).to have_attributes(status: 'ringing', sdp_offer: 'v=0 offer')
      expect(call.contact.name).to eq('Cliente de prueba')

      post "/api/v1/accounts/#{account.id}/whatsapp_calls/#{call.id}/accept", params: { sdp_answer: 'v=0 answer' },
                                                                              headers: admin.create_new_auth_token, as: :json
      expect(call.reload).to be_in_progress
      expect(senales).to include(hash_including('type' => 'answer', 'sdp' => 'v=0 answer'))
      expect(senales).to eq([])

      perform_enqueued_jobs(only: Webhooks::WhatsappCallEventsJob) do
        post "#{base}/hangup", params: { inbox_id: channel.inbox.id, call_id: call.provider_call_id, duration: 42 },
                               headers: admin.create_new_auth_token, as: :json
      end
      # El agente ya la tenía en curso: el terminate de Meta la cierra como completada.
      expect(call.reload).to have_attributes(status: 'completed', duration_seconds: 42)
    end
  end

  it 'el negocio llama: sin permiso lo pide, el cliente acepta y entonces sí suena en su lado' do
    conversation = create(:conversation, account: account, inbox: channel.inbox,
                                         contact_inbox: create(:contact_inbox, inbox: channel.inbox, source_id: wa_id))
    llamar = lambda do
      post "/api/v1/accounts/#{account.id}/whatsapp_calls/initiate",
           params: { conversation_id: conversation.display_id, sdp_offer: 'v=0 business' }, headers: admin.create_new_auth_token, as: :json
    end

    con_simulador do
      llamar.call
      expect(response.parsed_body['status']).to eq('permission_requested')
      solicitud = senales.find { |s| s['type'] == 'permission_request' }

      perform_enqueued_jobs(only: Webhooks::WhatsappCallEventsJob) do
        post "#{base}/permission", params: { inbox_id: channel.inbox.id, wa_id: wa_id, wamid: solicitud['wamid'], accept: true },
                                   headers: admin.create_new_auth_token, as: :json
      end
      expect(ActionCable.server).to have_received(:broadcast).with(admin.pubsub_token, hash_including(event: 'voice_call.permission_granted'))

      llamar.call
      expect(response).to have_http_status(:ok)
      expect(senales).to include(hash_including('type' => 'incoming', 'sdp' => 'v=0 business'))
    end
  end
end
