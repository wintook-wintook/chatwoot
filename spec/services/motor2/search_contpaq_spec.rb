# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 › «Qué sabe» con una fuente de CONTPAQi: no guarda nada en la plataforma, se le pregunta en
# vivo a su Agente de Servicio (el mismo cliente del 1.0). Antes se buscaba en lo guardado y salía vacío.
RSpec.describe Motor2::Search do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, phone_number: '+523121122345') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:source) do
    account.knowledge_sources.create!(source_type: 'contpaq_support', name: 'CONTPAQi', status: 'active',
                                      config: { 'base_url' => 'https://contpaq.test', 'client_id' => 'x', 'client_secret' => 'y',
                                                'token_url' => 'https://contpaq.test/token', 'scope' => 'z' })
  end
  let(:agent) { instance_double(Contpaq::ServiceAgent) }

  before { allow(Contpaq::ServiceAgent).to receive(:new).with(source).and_return(agent) }

  it 'le pregunta en vivo con el contacto y la conversación, y regresa su respuesta con la liga' do
    allow(agent).to receive(:answer).and_return(
      Contpaq::ServiceAgent::Result.new(answer: '1. Abre la factura. 2. Haz clic en Timbrar.',
                                        sources: [{ title: 'Manual', url: '' }, { title: 'Timbrar', url: 'https://docs.test/timbrar' }])
    )
    found = described_class.new(account, ["contpaq_support:#{source.id}"], conversation: conversation).call('¿cómo timbro?', only: 'CONTPAQi')

    expect(agent).to have_received(:answer).with(question: '¿cómo timbro?', user_id: '3121122345@kontrolya.com',
                                                 conversation_id: "acct-#{account.id}-conv-#{conversation.display_id}")
    row = found.find { |f| f[:fuente] == 'CONTPAQi' }[:resultados].first
    expect(row).to include(informacion: include('Haz clic en Timbrar'), liga: 'https://docs.test/timbrar')
  end

  it 'en el chat de prueba (sin conversación) pregunta con un identificador de prueba; si falla, no hay resultados' do
    allow(agent).to receive(:answer).and_return(Contpaq::ServiceAgent::Result.new(answer: nil, error: 'timeout'))
    found = described_class.new(account, ["contpaq_support:#{source.id}"]).call('¿cómo timbro?', only: 'CONTPAQi')

    expect(agent).to have_received(:answer).with(hash_including(user_id: start_with('prueba_'), conversation_id: nil))
    expect(found.find { |f| f[:fuente] == 'CONTPAQi' }[:resultados]).to eq([])
  end

  it 'le pregunta con las palabras del cliente, no con la búsqueda que redactó el modelo' do
    allow(agent).to receive(:answer).and_return(Contpaq::ServiceAgent::Result.new(answer: 'Catálogos > Clientes', sources: []))
    described_class.new(account, ["contpaq_support:#{source.id}"], customer_words: 'comp puedo dar de alta un cliente comercial premium')
                   .call('dar de alta cliente en CONTPAQi Comercial Premium', only: 'CONTPAQi')
    expect(agent).to have_received(:answer).with(hash_including(question: 'comp puedo dar de alta un cliente comercial premium'))
  end

  it 'si lo último que dijo es corto, va con lo que dijo antes' do
    runner = instance_double(Motor2::Runner)
    skill = Motor2::Skills::Knowledge.new(runner)
    skill.prepare([{ role: 'user', content: 'comp puedo dar de alta un cliente' }, { role: 'assistant', content: '¿En qué sistema?' },
                   { role: 'user', content: 'comercial premium' }])
    expect(skill.instance_variable_get(:@customer_words)).to eq('comp puedo dar de alta un cliente comercial premium')
  end
end
