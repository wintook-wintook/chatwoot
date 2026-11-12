# frozen_string_literal: true

require 'rails_helper'

# «Delegar seguimiento»: quién le da seguimiento ya (Seguimiento IA o un agente a medida, solo leído).
RSpec.describe 'Seguimiento IA — quién da seguimiento' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def running(params)
    get "/api/v1/accounts/#{account.id}/ai_follow_ups/running", params: params, headers: admin.create_new_auth_token, as: :json
    response.parsed_body
  end

  it 'sin nada corriendo ni agentes a medida' do
    expect(running(conversation_id: conversation.display_id)).to include('ai' => nil, 'custom' => nil, 'custom_agents' => false)
  end

  it 'dice qué agente a medida le da seguimiento y en qué conversación' do
    template = create(:tracking_template, account: account, name: 'Cobranza')
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: conversation,
                              tracking_template: template, status: 'scheduled')

    body = running(contact_id: contact.id)

    expect(body['custom']).to include('agent' => 'Cobranza', 'conversation_id' => conversation.display_id, 'status' => 'scheduled')
    expect(body['custom_agents']).to be(true)
  end

  it 'un seguimiento de agente a medida ya terminado no cuenta' do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: conversation, status: 'completed')
    expect(running(conversation_id: conversation.display_id)['custom']).to be_nil
  end

  it 'dice si corre un Seguimiento IA' do
    AiFollowUp.create!(account: account, conversation: conversation, contact: contact, objective: 'Saber cómo va', created_by: admin)
    expect(running(conversation_id: conversation.display_id)['ai']).to include('objective' => 'Saber cómo va')
  end
end
