# frozen_string_literal: true

require 'rails_helper'

# proyecto@contact_tracking — el trato (tú o usted) que va al final del turno de KBase sale del
# prompt del agente (ContactTrackings::CustomerTone.rule_for). Cuenta 613, convs 85 y 87: el
# prompt decía «Hablo de usted» y el turno decía «háblale de tú, salvo…»; el bot tuteaba.
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ana Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact,
                     content: '¿Desde cuándo puedo empezar a estudiar?')
  end
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }

  before do
    create(:integrations_hook, :openai, account: account)
    stub_request(:post, chat_url)
      .to_return(status: 200, body: { choices: [{ message: { content: 'Puede empezar en cualquier momento.' } }] }.to_json)
  end

  def ultimo_mensaje(prompt)
    tracking = create(:contact_tracking, account: account, contact: contact, inbox: inbox, complementary_prompt: prompt)
    described_class.new(message, tracking: tracking, branch: nil)
                   .send(:generate_contextual_reply, message.content, 'Se puede empezar en cualquier momento.')
    body = nil
    expect(a_request(:post, chat_url).with { |r| body = JSON.parse(r.body) }).to have_been_made
    body['messages'].last['content']
  end

  it 'con «Hablo de usted» en [ESTILO], el turno pide usted y ya no dice «háblale de tú»' do
    enviado = ultimo_mensaje("Agente de admisiones.\n\n[ESTILO]\nHablo de usted, con un tono profesional.")

    expect(enviado).to include(ContactTrackings::CustomerTone::RULE_USTED)
    expect(enviado).not_to include('háblale de tú')
  end

  it 'con «Hablo de tú», el turno pide tú' do
    expect(ultimo_mensaje("Agente.\n\n[ESTILO]\nHablo de tú.")).to include(ContactTrackings::CustomerTone::RULE_TU)
  end

  it 'si el prompt no dice el trato, queda la regla de siempre' do
    expect(ultimo_mensaje('Agente de admisiones.')).to include(ContactTrackings::CustomerTone::RULE)
  end
end
