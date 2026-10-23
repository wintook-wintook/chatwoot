# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — POST/GET …/assistant/conversation_review
RSpec.describe 'Asistente de Agentes IA — revisar una conversación real' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account) }
  let(:url)     { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/conversation_review" }
  let(:turn_id) { 'tabc12345' }

  def pedir(texto, user = admin)
    post url, params: { text: texto, turn_id: turn_id }, headers: user.create_new_auth_token, as: :json
  end

  it 'no deja entrar a un agente' do
    pedir("/app/accounts/#{account.id}/conversations/#{conversation.display_id}", agent)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'encola la revisión y responde 202' do
    expect do
      pedir("revisa /app/accounts/#{account.id}/conversations/#{conversation.display_id}")
    end.to have_enqueued_job(ContactTrackings::Assistant::ConversationReviewJob)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body['display_id']).to eq(conversation.display_id)
  end

  it '422 si el texto no trae una conversación, o no es de la cuenta' do
    pedir('hola')
    expect(response.parsed_body['error']).to eq('no_conversation')

    pedir("/app/accounts/#{account.id}/conversations/#{conversation.display_id + 10_000}")
    expect(response.parsed_body['error']).to eq('not_found')
  end

  it 'el resultado: 202 mientras trabaja, 200 al terminar' do
    get "#{url}/#{turn_id}", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:accepted)

    ContactTrackings::Assistant::TurnProgress.store_result(account, admin, turn_id, { summary: 'ok' })
    get "#{url}/#{turn_id}", headers: admin.create_new_auth_token
    expect(response.parsed_body).to eq('summary' => 'ok')
  end
end
