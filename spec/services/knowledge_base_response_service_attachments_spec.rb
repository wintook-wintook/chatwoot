# frozen_string_literal: true

require 'rails_helper'

# proyecto@ai_agent_attachments — {{nombre}} en una rama CON fuente. El nombre del archivo
# viene de una columna de la hoja (cuenta 568, «imagen promocion», 30/09/2026): antes el
# token le llegaba literal al cliente.
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ana Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact,
                     content: '¿Qué beca tiene Derecho?')
  end
  let(:source) do
    create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'CATALOGO DE CARRERAS',
                              config: { 'sheet_mode' => 'faq' })
  end
  let(:fila) do
    KnowledgeItem.new(title: 'CATALOGO DE CARRERAS — fila 3',
                      content: "carrera: Derecho\nPRIMERA BECA: 28%\nimagen promocion: imagen_promo2")
  end
  let(:template) { create(:tracking_template, account: account) }
  let!(:adjunto) { create(:ai_agent_attachment, tracking_template: template, account: account, name: 'imagen_promo2') }
  let(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, tracking_template: template,
                              complementary_prompt: 'Si hay imagen promocion, envíala.')
  end
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }

  before do
    create(:integrations_hook, :openai, account: account)
    stub_request(:post, chat_url).to_return(
      status: 200, body: { choices: [{ message: { content: 'Derecho tiene 28% de beca. {{imagen_promo2}}' } }] }.to_json
    )
  end

  def contestar
    described_class.new(message, tracking: tracking, branch: nil).tap do |service|
      allow(service).to receive(:search_items).and_return([fila])
    end.send(:perform_sheet_faq, message.content, source)
    conversation.messages.outgoing.last
  end

  it 'manda el archivo del Agente IA y el cliente no ve el {{…}}' do
    enviado = contestar

    expect(enviado.content).to include('Derecho tiene 28% de beca.')
    expect(enviado.content).not_to include('{{')
    expect(enviado.attachments.first.file.blob).to eq(adjunto.file.blob)
  end

  it 'le dice al modelo cómo pedir el archivo, porque el agente tiene archivos' do
    contestar

    body = nil
    expect(a_request(:post, chat_url).with { |r| body = JSON.parse(r.body) }).to have_been_made
    expect(body['messages'].first['content']).to include('ENVÍO DE ARCHIVOS')
  end

  it 'guarda en el historial que ya lo mandó, no el token: si no, lo reenvía en cada turno' do
    contestar

    respuesta = conversation.reload.additional_attributes['kb_history'].last['a']
    expect(respuesta).to include('(archivo enviado: imagen_promo2)')
    expect(respuesta).not_to include('{{')
  end

  it 'un nombre que el agente no tiene no se manda, pero tampoco llega literal' do
    stub_request(:post, chat_url).to_return(
      status: 200, body: { choices: [{ message: { content: 'Derecho tiene 28%. {{imagen_promo9}}' } }] }.to_json
    )

    enviado = contestar

    expect(enviado.content).not_to include('{{')
    expect(enviado.attachments).to be_empty
  end
end
