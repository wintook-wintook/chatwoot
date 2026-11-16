# frozen_string_literal: true

require 'rails_helper'

# proyecto@contact_tracking — cuando la fuente no contesta, CÓMO decirlo es del Entrenamiento.
# Cuenta 1128, conv 300 (16/11/2026): la frase fija «aclara que no tienes el procedimiento
# exacto» iba pegada a la pregunta y el bot contestó «Lamentablemente, no tengo el
# procedimiento exacto…» aunque el prompt pedía otra frase y compartir el WhatsApp.
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ana Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact,
                     content: '¿Dónde veo mis calificaciones?')
  end
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }

  before do
    create(:integrations_hook, :openai, account: account)
    stub_request(:post, chat_url)
      .to_return(status: 200, body: { choices: [{ message: { content: 'Ese dato no lo tengo a la mano.' } }] }.to_json)
  end

  def ultimo_mensaje(prompt)
    tracking = create(:contact_tracking, account: account, contact: contact, inbox: inbox, complementary_prompt: prompt)
    described_class.new(message, tracking: tracking, branch: nil)
                   .send(:generate_contextual_reply, message.content, 'Se puede empezar en cualquier momento.')
    body = nil
    expect(a_request(:post, chat_url).with { |r| body = JSON.parse(r.body) }).to have_been_made
    body['messages'].last['content']
  end

  it 'con [SIN INFORMACIÓN] en el Entrenamiento, el motor manda a esa sección y prohíbe inventar' do
    enviado = ultimo_mensaje("Agente de admisiones.\n\n[SIN INFORMACIÓN]\nComparto el WhatsApp 55 1234 5678.")

    expect(enviado).to include(ContactTrackings::MissingAnswer::NO_INVENT, ContactTrackings::MissingAnswer::WITH_SECTION)
    expect(enviado).not_to include('procedimiento exacto')
    expect(enviado).not_to include('pasarlo con un asesor')
  end

  it 'con Entrenamiento sin esa sección, prohíbe inventar y deja una indicación neutral' do
    enviado = ultimo_mensaje('Agente de admisiones.')

    expect(enviado).to include(ContactTrackings::MissingAnswer::NO_INVENT, ContactTrackings::MissingAnswer::WITHOUT_SECTION)
    expect(enviado).not_to include('procedimiento exacto')
  end

  it 'sin Entrenamiento, queda la redacción por defecto' do
    expect(ultimo_mensaje('')).to include(ContactTrackings::MissingAnswer::DEFAULT)
  end
end
