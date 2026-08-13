# frozen_string_literal: true

# proyecto@ai_agent_assistant - F7
require 'rails_helper'

RSpec.describe AiAgentAssistant::AutoConversation do
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
  end

  def completion(text, tokens: 20)
    { status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: text }, finish_reason: 'stop' }],
              usage: { completion_tokens: tokens } }.to_json }
  end

  def router(intent = 'tracking')
    { status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: { intent: intent, confidence: 0.5 }.to_json } }] }.to_json }
  end

  describe 'personalidad' do
    it 'cae a «interesado» si la personalidad no existe' do
      stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_return(completion('Hola.'))

      expect(described_class.new(template, persona: 'marciano', turns: 1).call['persona'])
        .to eq('interested')
    end
  end

  describe 'tope de turnos' do
    it 'no pasa del máximo aunque se pidan más: cada turno cuesta dos llamadas' do
      servicio = described_class.new(template, turns: 99)

      expect(servicio.send(:turns)).to eq(described_class::MAX_TURNS)
    end
  end

  describe 'la conversación' do
    it 'alterna agente y cliente y suma los tokens gastados' do
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_return(completion('Hola, te escribo por la factura.', tokens: 25), # apertura del agente
                   completion('No sé de qué me hablas.'), # cliente simulado
                   completion('Es la factura 1042 del mes pasado.', tokens: 30), # agente
                   router,
                   completion('Ah, esa ya la pagué.'),                           # cliente
                   completion('Perfecto, lo verifico y te confirmo.', tokens: 28), # agente
                   router('interested'))

      resultado = described_class.new(template, turns: 2).call

      expect(resultado['turns'].pluck('role')).to eq(%w[agent customer agent customer agent])
      expect(resultado['tokens_used']).to eq(83)
      expect(resultado['loop_detected']).to be(false)
    end

    # Lo que un humano probando a mano no llega a ver, porque prueba dos turnos y se cansa.
    it 'corta y avisa cuando el agente empieza a repetirse' do
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_return(completion('¿Pudiste revisar la factura pendiente?'),
                   completion('Ya te dije que no.'),
                   completion('¿Pudiste revisar la factura pendiente?'),
                   router,
                   completion('Que no.'),
                   completion('otra cosa distinta del todo'),
                   router)

      resultado = described_class.new(template, turns: 5).call

      expect(resultado['loop_detected']).to be(true)
      # Se detuvo en el bucle en vez de gastar los cinco turnos.
      expect(resultado['turns'].count { |t| t['role'] == 'agent' }).to eq(2)
    end
  end

  describe 'sin integración de OpenAI' do
    it 'no intenta conversar' do
      account.hooks.find_by(app_id: 'openai').destroy!

      resultado = described_class.new(template).call
      expect(resultado['error']).to eq('openai_not_configured')
      expect(resultado['turns']).to be_empty
    end
  end
end
