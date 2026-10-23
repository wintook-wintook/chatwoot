# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F7) — el navegador sube la grabación al colgar.
RSpec.describe 'Llamadas de WhatsApp — grabación' do
  let(:channel) { calling_channel }
  let(:account) { channel.account }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox) }
  let(:grabar) { true }
  let(:call) do
    create(:call, account: account, inbox: channel.inbox, conversation: conversation, contact: conversation.contact,
                  status: 'completed', meta: { 'recording_enabled' => grabar })
  end
  let(:url) { "/api/v1/accounts/#{account.id}/whatsapp_calls/#{call.id}/upload_recording" }

  before do
    allow(ActionCable.server).to receive(:broadcast)
    create(:inbox_member, inbox: channel.inbox, user: agente)
    Voice::CallMessageBuilder.new(call).perform!.tap { |m| call.update!(message: m) }
  end

  def subir(archivo = fixture_file_upload(Rails.root.join('spec/assets/sample.ogg'), 'audio/ogg'))
    post url, params: { recording: archivo }, headers: agente.create_new_auth_token
  end

  it 'queda como audio del mensaje de la llamada; una segunda subida no se duplica' do
    subir
    expect(response.parsed_body['status']).to eq('uploaded')
    expect(call.message.reload.attachments.where(file_type: :audio).count).to eq(1)
    expect(call.message.content_attributes.dig('data', 'recorded')).to be(true)

    subir
    expect(response.parsed_body['status']).to eq('already_uploaded')
    expect(call.message.reload.attachments.count).to eq(1)
  end

  it 'si no es audio, 422' do
    subir(fixture_file_upload(Rails.root.join('spec/assets/sample.pdf'), 'application/pdf'))
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'sin archivo, 422' do
    post url, headers: agente.create_new_auth_token
    expect(response).to have_http_status(:unprocessable_entity)
  end

  describe 'si la grabación estaba apagada al empezar la llamada' do
    let(:grabar) { false }

    it 'no la guarda (una pestaña vieja podría intentarlo)' do
      subir
      expect(response).to have_http_status(:unprocessable_entity)
      expect(call.message.reload.attachments).to be_empty
    end
  end
end
