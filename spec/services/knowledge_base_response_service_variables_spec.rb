# frozen_string_literal: true

require 'rails_helper'

# proyecto@contact_tracking — lo que va al final del turno de KBase con un Entrenamiento propio:
# el recordatorio de la línea VARIABLES y su estilo (sin «completa y útil»).
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ana Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact,
                     content: '¿Cuánto cuesta Psicología?')
  end
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }
  let(:con_variables) do
    "Agente de admisiones.\n\n[VARIABLES]\nCARRERA=VACÍO|valor\nInicial: CARRERA=VACÍO."
  end

  before do
    create(:integrations_hook, :openai, account: account)
    stub_request(:post, chat_url)
      .to_return(status: 200, body: { choices: [{ message: { content: 'Cuesta $3,221 por materia.' } }] }.to_json)
  end

  def ultimo_mensaje(tracking)
    described_class.new(message, tracking: tracking, branch: nil)
                   .send(:generate_contextual_reply, message.content, 'carrera: Psicología')
    body = nil
    expect(a_request(:post, chat_url).with { |r| body = JSON.parse(r.body) }).to have_been_made
    body['messages'].last['content']
  end

  def tracking_con(prompt)
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, complementary_prompt: prompt)
  end

  it 'con [VARIABLES], el último mensaje pide cerrar con la línea VARIABLES' do
    expect(ultimo_mensaje(tracking_con(con_variables))).to include('«VARIABLES: …»')
  end

  it 'sin [VARIABLES], no hay recordatorio' do
    expect(ultimo_mensaje(tracking_con('Agente de admisiones.'))).not_to include('VARIABLES')
  end

  it 'con Entrenamiento propio manda su estilo, no «completa y útil» ni ofrecer un asesor' do
    enviado = ultimo_mensaje(tracking_con('Agente de admisiones.'))

    expect(enviado).to include(described_class::AGENT_STYLE_RULE)
    expect(enviado).not_to include('completa y útil')
    expect(enviado).not_to include('ofrece pasarlo con un asesor')
  end

  it 'en una conversación nueva le dice que es el primer mensaje' do
    expect(ultimo_mensaje(tracking_con('Agente de admisiones.'))).to start_with(described_class::FIRST_TURN_NOTE)
  end

  it 'si el equipo ya escribió, le dice que no es el primer mensaje' do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                     content: 'Sí, buen día. Soy Danielle.', created_at: 1.minute.ago)
    message

    expect(ultimo_mensaje(tracking_con('Agente de admisiones.'))).to start_with(described_class::LATER_TURN_NOTE)
  end

  it 'sin Entrenamiento, lo de siempre' do
    enviado = ultimo_mensaje(nil)

    expect(enviado).to include('completa y útil')
    expect(enviado).to include('ofrece pasarlo con un asesor')
    expect(enviado).not_to include('Contexto:')
  end
end
