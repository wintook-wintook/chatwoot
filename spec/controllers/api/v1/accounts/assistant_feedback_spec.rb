# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Asistente (Dali) — 👎 a una respuesta', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:thread) do
    AssistantThread.create!(account: account, user: agent).tap do |t|
      t.add_message(role: 'user', content: '¿Cómo facturo?', context: { 'page' => 'home' })
      t.add_message(role: 'assistant', content: 'No lo tengo documentado.')
    end
  end
  let(:answer_id) { thread.reload.messages.last['id'] }

  it 'marca la respuesta y anota la pregunta para el Super Admin' do
    post "/api/v1/accounts/#{account.id}/assistant/messages/#{answer_id}/feedback",
         headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(thread.reload.messages.last['feedback']).to eq('down')
    expect(AssistantGuideGap.last).to have_attributes(reason: 'thumbs_down', question: '¿Cómo facturo?',
                                                      answer: 'No lo tengo documentado.', page: 'home', user_id: agent.id)
  end

  it 'no acepta mensajes del usuario' do
    user_id = thread.reload.messages.first['id']
    post "/api/v1/accounts/#{account.id}/assistant/messages/#{user_id}/feedback",
         headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
    expect(AssistantGuideGap.count).to eq(0)
  end
end
