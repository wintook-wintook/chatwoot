# frozen_string_literal: true

# proyecto@ai_agent_assistant - F7
require 'rails_helper'

RSpec.describe AiAgentAssistant::SandboxService do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account) }
  let(:template) do
    create(:tracking_template, account: account, inbox: inbox, name: 'Cobranza',
                               objective: 'Confirmar el pago de la factura vencida.',
                               complementary_prompt: 'Eres del área de cobranza. Trato de usted.')
  end

  def with_key
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                               settings: { 'api_key' => 'sk-de-prueba' })
  end

  # Respuesta del modelo con `usage` y `finish_reason`: es lo que convierte el
  # probador en una medición y no en una impresión.
  def stub_completion(text, tokens: 40, finish: 'stop')
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                 body: { choices: [{ message: { content: text }, finish_reason: finish }],
                         usage: { completion_tokens: tokens } }.to_json)
  end

  describe 'sin integración de OpenAI' do
    it 'lo dice en vez de devolver un turno vacío' do
      expect(described_class.new(template).opening['error']).to eq('openai_not_configured')
    end
  end

  describe '#opening' do
    before { with_key }

    it 'devuelve el mensaje inicial con su modelo y su tope' do
      stub_completion('Hola Juan, te escribo por la factura pendiente.')

      resultado = described_class.new(template, attempt: 1).opening

      expect(resultado['text']).to include('factura')
      expect(resultado['max_tokens']).to eq(150)
      expect(resultado['tokens_used']).to eq(40)
      expect(resultado['truncated']).to be(false)
    end

    # La evidencia directa de T1: el tope corta la respuesta a media frase.
    it 'marca cuando el tope truncó la respuesta' do
      stub_completion('Hola Juan, te escribo porque', tokens: 150, finish: 'length')

      expect(described_class.new(template).opening['truncated']).to be(true)
    end

    it 'lista lo que habría pasado, sin que pase' do
      stub_completion('Hola Juan.')

      resultado = described_class.new(template).opening
      expect(resultado['would_have']).to include('send_message', 'consume_attempt')
    end
  end

  describe '#reply' do
    before { with_key }

    it 'contesta y clasifica con el router real' do
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_return(
          { status: 200, headers: { 'Content-Type' => 'application/json' },
            body: { choices: [{ message: { content: 'Perfecto, lo confirmo.' }, finish_reason: 'stop' }],
                    usage: { completion_tokens: 30 } }.to_json },
          { status: 200, headers: { 'Content-Type' => 'application/json' },
            body: { choices: [{ message: { content: { intent: 'interested', confidence: 0.86 }.to_json } }] }.to_json }
        )

      resultado = described_class.new(template).reply('ya la pagué la semana pasada')

      expect(resultado['text']).to include('confirmo')
      expect(resultado['route'][:route]).to eq(:interested)
      expect(resultado['route'][:confidence]).to eq(0.86)
    end

    it 'detecta la palabra clave que dispararía, SIN ejecutarla' do
      template.update!(keyword_actions: [{ 'keyword' => 'ya pagué', 'action' => 'objective_met',
                                           'direction' => 'incoming' }])
      stub_completion('Gracias.')

      resultado = described_class.new(template).reply('ya pagué ayer')

      expect(resultado['keyword_action']['action']).to eq('objective_met')
      expect(resultado['would_have']).to include('keyword_objective_met')
    end

    it 'anuncia la búsqueda de conocimiento cuando hay una directiva de búsqueda' do
      template.update!(complementary_prompt: '@buscar_articulo')
      stub_completion('Según el artículo…')

      expect(described_class.new(template).reply('¿cómo lo configuro?')['would_have'])
        .to include('search_knowledge')
    end

    it 'anuncia agendar y crear ticket cuando esas banderas están en el prompt' do
      template.update!(complementary_prompt: "@agendar_calendar\n@crear_ticket(tipo=SOPORTE)")
      stub_completion('Te agendo.')

      efectos = described_class.new(template).reply('quiero una cita')['would_have']
      expect(efectos).to include('book_appointment', 'create_ticket')
    end
  end

  describe 'efectos apagados por diseño' do
    before { with_key }

    it 'no crea ningún mensaje ni seguimiento' do
      stub_completion('Hola.')

      expect do
        described_class.new(template).reply('hola')
      end.to not_change(Message, :count).and not_change(ContactTracking, :count)
    end

    it 'no ejecuta la acción de la palabra clave sobre nada' do
      template.update!(keyword_actions: [{ 'keyword' => 'cancelen', 'action' => 'cancel',
                                           'direction' => 'incoming' }])
      stub_completion('Entendido.')

      expect do
        described_class.new(template).reply('cancelen todo por favor')
      end.not_to(change { template.reload.updated_at })
    end
  end
end
