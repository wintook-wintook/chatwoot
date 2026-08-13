# frozen_string_literal: true

# proyecto@ai_agent_assistant - F5
require 'rails_helper'

RSpec.describe AiAgentAssistant::ConversationService do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }
  let(:inbox)   { create(:inbox, account: account) }
  let(:session) do
    account.ai_agent_assistant_sessions.create!(user: user, mode: 'interview',
                                                step: 'objective', draft: {})
  end

  def stub_openai(payload)
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                 body: { choices: [{ message: { content: payload.to_json } }] }.to_json)
  end

  def with_key
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                               settings: { 'api_key' => 'sk-de-prueba' })
  end

  describe 'sin integración de OpenAI en la cuenta' do
    # Degradar en silencio sería peor: el usuario creería que el asistente «no tiene nada
    # que decir» cuando lo que falta es la llave.
    it 'lo dice en vez de fingir un turno' do
      turn = described_class.new(session).call('hola')

      expect(turn['error']).to eq('openai_not_configured')
      expect(turn['reply']).to be_nil
      expect(session.reload.messages).to be_empty
    end
  end

  describe 'un turno normal' do
    before { with_key }

    it 'guarda la conversación y propone por campo' do
      stub_openai(reply: '¿Cuenta como cumplido solo el pago, o también una fecha compromiso?',
                  proposals: [{ field: 'objective', value: 'Confirmar el pago de la factura vencida.',
                                rationale: 'Es verificable' }],
                  next_step: 'audience', done: false)

      turn = described_class.new(session).call('quiero cobrar')

      expect(turn['reply']).to include('fecha compromiso')
      expect(turn['proposals'].first['field']).to eq('objective')
      expect(session.reload.messages.pluck('role')).to eq(%w[user assistant])
      expect(session.step).to eq('audience')
    end

    # El borrador solo cambia cuando el usuario acepta. Proponer no es aplicar.
    it 'no toca el borrador al proponer' do
      stub_openai(reply: 'ok', proposals: [{ field: 'objective', value: 'Algo' }])

      expect { described_class.new(session).call('hola') }
        .not_to(change { session.reload.draft })
      expect(session.proposals.pluck('field')).to eq(['objective'])
    end

    it 'un turno de apertura no necesita mensaje del usuario' do
      stub_openai(reply: '¿Qué tiene que pasar para darlo por cumplido?', proposals: [])

      turn = described_class.new(session).call

      expect(turn['reply']).to be_present
      expect(session.reload.messages.pluck('role')).to eq(['assistant'])
    end
  end

  describe 'saneado de lo que devuelve el modelo' do
    before { with_key }

    it 'descarta campos que no existen en el Agente IA' do
      stub_openai(reply: 'ok', proposals: [{ field: 'superpoder', value: 'volar' },
                                           { field: 'objective', value: 'Cobrar la factura vencida.' }])

      turn = described_class.new(session).call('x')

      expect(turn['proposals'].pluck('field')).to eq(['objective'])
    end

    # Invariante 2: no puede proponer lo que en esta cuenta no existe.
    it 'descarta un inbox que no es de la cuenta' do
      ajeno = create(:inbox, account: create(:account))
      stub_openai(reply: 'ok', proposals: [{ field: 'inbox_id', value: ajeno.id }])

      expect(described_class.new(session).call('x')['proposals']).to be_empty
    end

    it 'acepta un inbox que sí es de la cuenta' do
      stub_openai(reply: 'ok', proposals: [{ field: 'inbox_id', value: inbox.id }])

      expect(described_class.new(session).call('x')['proposals'].first['value']).to eq(inbox.id)
    end

    # Una acción mal formada tumbaría el guardado entero por la validación del modelo.
    it 'filtra las palabras clave con acción o dirección inválida' do
      acciones = [{ 'keyword' => 'pagado', 'action' => 'inventada', 'direction' => 'incoming' },
                  { 'keyword' => 'ya pagué', 'action' => 'objective_met', 'direction' => 'incoming' },
                  { 'keyword' => '', 'action' => 'cancel', 'direction' => 'incoming' }]
      stub_openai(reply: 'ok', proposals: [{ field: 'keyword_actions', value: acciones }])

      valores = described_class.new(session).call('x')['proposals'].first['value']
      expect(valores.pluck('keyword')).to eq(['ya pagué'])
    end

    it 'descarta una propuesta que no cambia nada' do
      session.update!(draft: { 'objective' => 'Cobrar la factura vencida.' })
      stub_openai(reply: 'ok', proposals: [{ field: 'objective', value: 'Cobrar la factura vencida.' }])

      expect(described_class.new(session).call('x')['proposals']).to be_empty
    end

    it 'ignora un paso siguiente que no existe en el guion' do
      stub_openai(reply: 'ok', proposals: [], next_step: 'paso_inventado')

      described_class.new(session).call('x')
      expect(session.reload.step).to eq('objective')
    end

    it 'no se cae si el modelo devuelve algo que no es JSON' do
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                   body: { choices: [{ message: { content: 'lo siento, no puedo' } }] }.to_json)

      expect(described_class.new(session).call('x')['error']).to eq('model_unavailable')
    end
  end

  describe 'valida su propia propuesta (invariante 7)' do
    before { with_key }

    it 'devuelve los hallazgos del linter junto con la propuesta' do
      stub_openai(reply: 'Te propongo buscar en el foro.',
                  proposals: [{ field: 'complementary_prompt',
                                value: "@discourse\n#{'Instrucciones muy detalladas. ' * 30}" }])

      turn = described_class.new(session).call('quiero que conteste dudas')

      expect(turn['findings'].pluck(:rule)).to include(:search_swallows_prompt)
    end

    it 'no devuelve hallazgos cuando la propuesta está bien formada' do
      stub_openai(reply: 'ok',
                  proposals: [{ field: 'objective', value: 'Confirmar el pago de la factura vencida.' },
                              { field: 'complementary_prompt', value: 'Eres del área de cobranza. Trato de usted.' },
                              { field: 'inbox_id', value: inbox.id }])

      # Queda un `info` («el objetivo parece un título»): es una observación, no un defecto.
      hallazgos = described_class.new(session).call('x')['findings']
      expect(hallazgos.pluck(:level).uniq).to eq([:info])
    end
  end
end
