# frozen_string_literal: true

# proyecto@ai_agent_assistant - F7
require 'rails_helper'

RSpec.describe AiAgentAssistant::Replay do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account) }
  let(:template) do
    create(:tracking_template, account: account, inbox: inbox, name: 'Cobranza',
                               objective: 'Confirmar el pago de la factura vencida.',
                               complementary_prompt: 'Eres del área de cobranza.')
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                               settings: { 'api_key' => 'sk-de-prueba' })
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                 body: { choices: [{ message: { content: 'Lo que diría el agente.' },
                                     finish_reason: 'stop' }],
                         usage: { completion_tokens: 22 } }.to_json)
  end

  # El estado se fija DESPUÉS de los mensajes: un mensaje entrante reabre la
  # conversación, así que ponerlo antes no sobreviviría.
  def conversation_with(customer:, human:, status: :resolved, in_inbox: inbox)
    contact = create(:contact, account: account)
    conversation = create(:conversation, account: account, inbox: in_inbox, contact: contact)
    create(:message, account: account, inbox: in_inbox, conversation: conversation,
                     message_type: :incoming, content: customer, created_at: 2.hours.ago)
    create(:message, account: account, inbox: in_inbox, conversation: conversation,
                     message_type: :outgoing, content: human, created_at: 1.hour.ago)
    conversation.update!(status: status)
    conversation
  end

  describe 'sin material con el que comparar' do
    it 'avisa cuando el agente no tiene inbox asignado' do
      template.update!(inbox: nil)

      expect(described_class.new(template).call['error']).to eq('no_inbox')
    end

    it 'avisa cuando el inbox no tiene conversaciones cerradas' do
      conversation_with(customer: 'Hola, tengo una duda del pago', human: 'Claro, te ayudo',
                        status: :open)

      expect(described_class.new(template).call['error']).to eq('no_conversations')
    end
  end

  describe 'la comparación' do
    it 'pone lo que dijo la persona al lado de lo que diría el agente' do
      conversation_with(customer: 'Ya deposité el lunes pasado',
                        human: 'Gracias, lo verifico y te confirmo hoy mismo')

      caso = described_class.new(template).call['cases'].first

      expect(caso['customer']).to eq('Ya deposité el lunes pasado')
      expect(caso['human']).to eq('Gracias, lo verifico y te confirmo hoy mismo')
      expect(caso['agent']).to eq('Lo que diría el agente.')
      expect(caso['tokens_used']).to eq(22)
    end

    it 'no cruza inboxes: solo conversaciones del canal del agente' do
      otro = create(:inbox, account: account)
      conversation_with(customer: 'Mensaje de otro canal distinto', human: 'Respuesta ajena',
                        in_inbox: otro)

      expect(described_class.new(template).call['error']).to eq('no_conversations')
    end

    it 'descarta conversaciones sin respuesta humana con la que comparar' do
      contact = create(:contact, account: account)
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact,
                                           status: :resolved)
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       message_type: :incoming, content: 'Nadie me contestó nunca')

      expect(described_class.new(template).call['error']).to eq('no_conversations')
    end

    # Cada conversación cuesta una llamada al modelo: el tope es duro a propósito.
    it 'nunca corre más conversaciones que el máximo' do
      6.times { |i| conversation_with(customer: "Mensaje del cliente #{i}", human: "Respuesta #{i}") }

      resultado = described_class.new(template, limit: 99).call

      expect(resultado['cases'].size).to eq(described_class::MAX_CONVERSATIONS)
    end
  end

  describe 'solo lectura' do
    it 'no crea mensajes ni reabre la conversación' do
      conversation = conversation_with(customer: 'Ya deposité el lunes', human: 'Lo verifico')

      expect { described_class.new(template).call }.not_to change(Message, :count)
      expect(conversation.reload.status).to eq('resolved')
    end
  end
end
