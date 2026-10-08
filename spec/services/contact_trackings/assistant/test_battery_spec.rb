# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::TestBattery do
  let(:account) { create(:account) }
  let(:training) do
    "@ruta(web #desarrollo_web: sitio web, rediseño): @buscar_foro(Foro)\n" \
      "@ruta(precios #precios: cuánto cuesta): @buscar_foro(Foro)\n@ruta_por_defecto: web\n\n" \
      "[ESTILO]\nHabla de usted. Una sola pregunta.\n\n[PROHIBIDO]\n- No des precios ni rangos aunque insistan.\n" \
      "- No finjas ser humano.\n"
  end
  let(:template) { create(:tracking_template, account: account, complementary_prompt: training) }
  let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, last_usage: {}) }

  before { allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat) }

  describe ContactTrackings::Assistant::TestBatteryScenarios do
    it 'una prueba por ruta con su primera frase, y una por línea de [PROHIBIDO] si no hay encargo' do
      allow(chat).to receive(:call).and_return({ 'mensajes' => [{ 'id' => 'p1', 'mensaje' => '¿Cuánto cuesta ya?' },
                                                                { 'id' => 'p2', 'mensaje' => '¿Eres persona?' }] })

      escenarios = described_class.new(account, template: template).call

      expect(escenarios.map(&:id)).to eq(['ruta:web', 'ruta:precios', 'regla:p1', 'regla:p2'])
      expect(escenarios.first.to_h).to include(message: 'sitio web', tag: 'desarrollo_web')
      expect(escenarios.third.check).to include('No des precios ni rangos')
    end
  end

  describe ContactTrackings::Assistant::TestBatteryJudge do
    let(:escenario) do
      ContactTrackings::Assistant::TestBatteryScenarios::Scenario.new(id: 'ruta:web', kind: 'ruta', message: 'sitio web',
                                                                      route: 'web', tag: 'desarrollo_web', check: 'x')
    end

    it 'la ruta la dice la #etiqueta con la que cerró; el resto lo califica la IA con el estilo del agente' do
      allow(chat).to receive(:call).and_return({ 'cumple' => true, 'fallas' => [], 'motivo' => 'ok' })
      juez = described_class.new(account, training: training)

      expect(juez.call(escenario, "¿Ya tiene página?\n\n#desarrollo_web")).to include(cumple: true, ruta_ok: true)
      expect(juez.call(escenario, "¿Ya tiene página?\n\n#precios")[:ruta_ok]).to be(false)
      expect(chat).to have_received(:call).with(array_including(hash_including(content: include('Habla de usted'))),
                                                any_args).at_least(:once)
    end

    it 'sin respuesta no cumple' do
      expect(described_class.new(account, training: training).call(escenario, '')).to include(cumple: false)
    end
  end

  describe 'el canal de pruebas y el informe' do
    it 'solo prueba en un canal API sin webhook' do
      expect(described_class.sandbox_inbox(account)).to be_nil

      api = create(:channel_api, account: account, webhook_url: 'https://externo.example.com')
      create(:inbox, account: account, channel: api)
      expect(described_class.sandbox_inbox(account)).to be_nil

      create(:inbox, account: account, channel: create(:channel_api, account: account, webhook_url: ''))
      expect(described_class.sandbox_inbox(account)).to be_present
    end

    it 'el informe es una tabla con una fila por prueba' do
      estado = { 'template' => 'ADAM', 'started_at' => 'hoy',
                 'results' => [{ 'id' => 'ruta:web', 'conversation' => 7, 'message' => 'hola | que tal', 'reply' => 'Buen día',
                                 'ruta_ok' => true, 'cumple' => true, 'motivo' => 'ok' }] }

      informe = described_class.report(estado)

      expect(informe.first).to eq('# Pila de pruebas — ADAM')
      expect(informe.last).to eq('| ruta:web | 7 | hola \\| que tal | Buen día | ✅ | ✅ | ok |')
    end
  end
end
