# frozen_string_literal: true

require 'rails_helper'

# proyecto@diagrama_agente_ia F3 — docs/diagrama_agente_ia_plan.md §6 y §9.1
RSpec.describe ContactTrackings::Assistant::TestCases do
  let(:account) { create(:account) }
  let(:training) do
    "@ruta(cotizar #cotizar: precios, cotización): -\n@ruta(soporte #soporte: no funciona): -\n" \
      "@ruta_por_defecto: soporte\n\n[PROHIBIDO]\n- No inventes precios.\n"
  end
  let(:template) { create(:tracking_template, account: account, complementary_prompt: training) }
  let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, last_usage: {}) }

  before do
    allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat)
    allow(chat).to receive(:call).and_return({ 'mensajes' => [{ 'id' => 'p1', 'mensaje' => '¿Me das un precio aprox?' }] })
  end

  describe '.generate' do
    it 'crea una por ruta y una por regla, y generar otra vez no duplica' do
      creados = described_class.generate(account, template)

      expect(creados.map(&:source_key)).to eq(['ruta:cotizar', 'ruta:soporte', 'regla:p1'])
      expect(template.test_cases.find_by(source_key: 'ruta:cotizar'))
        .to have_attributes(kind: 'ruta', expected_route: 'cotizar', message: 'precios')
      expect(described_class.generate(account, template)).to be_empty
      expect(template.test_cases.count).to eq(3)
    end
  end

  describe '.add_own y el tope' do
    it 'agrega la escrita a mano al final' do
      described_class.generate(account, template)
      caso = described_class.add_own(account, template, '  ¿abren domingo?  ')

      expect(caso).to have_attributes(kind: 'propia', message: '¿abren domingo?', position: 4)
    end

    it 'una sugerida con su ruta esperada es de ruta' do
      caso = described_class.add_own(account, template, '¿cuánto sale?', expected_route: 'Cotizar')

      expect(caso).to have_attributes(kind: 'ruta', expected_route: 'cotizar', check_text: include('cotizar'))
    end

    it 'no pasa del tope por agente' do
      stub_const('TrackingTestCase::MAX_PER_TEMPLATE', 1)
      described_class.add_own(account, template, 'uno')

      expect(described_class.add_own(account, template, 'dos')).not_to be_persisted
    end
  end

  describe '.dry_path' do
    it 'la firma cambia con la ruta o la fuente, no con la similitud' do
      base = { routes: { chosen: 'cotizar' }, source: { mode: 'google_doc', items: [{ similarity: 0.8 }] }, tag: '#cotizar' }
      otra_similitud = base.deep_merge(source: { items: [{ similarity: 0.5 }] })
      otra_ruta = base.deep_merge(routes: { chosen: 'soporte' })

      expect(described_class.dry_path(base)).to eq(described_class.dry_path(otra_similitud))
      expect(described_class.dry_path(base)).not_to eq(described_class.dry_path(otra_ruta))
    end
  end

  describe 'TestCasesDryJob' do
    let(:resultado) { ContactTrackings::Assistant::DryRunService::Result }

    def informe(ruta)
      { routes: { chosen: ruta }, source: { reason: :no_source }, tag: "##{ruta}", case: { creates: false } }
    end

    it 'corre cada prueba, guarda el anterior y anota las que cambiaron de camino' do
      # En test la caché es null_store: el avance vive en la caché.
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      caso = described_class.add_own(account, template, '¿precio?')
      servicio = instance_double(ContactTrackings::Assistant::DryRunService)
      allow(ContactTrackings::Assistant::DryRunService).to receive(:new).and_return(servicio)

      allow(servicio).to receive(:call).and_return(resultado.new(payload: informe('cotizar')))
      ContactTrackings::Assistant::TestCasesDryJob.perform_now(account.id, template.id, training)
      expect(caso.reload.last_dry.dig('informe', 'routes', 'chosen')).to eq('cotizar')
      expect(caso.dry_changed?).to be_nil

      allow(servicio).to receive(:call).and_return(resultado.new(payload: informe('soporte')))
      ContactTrackings::Assistant::TestCasesDryJob.perform_now(account.id, template.id, training, nil, 'publish')

      expect(caso.reload.dry_changed?).to be(true)
      expect(caso.previous_dry.dig('informe', 'routes', 'chosen')).to eq('cotizar')
      expect(described_class.dry_status(template)).to include('status' => 'done', 'trigger' => 'publish',
                                                              'changed' => [caso.id], 'done' => 1)
    end
  end

  describe 'lo que se ofrece en vivo al publicar' do
    it 'las que cambiaron, las rojas y las fijadas, con su costo estimado' do
      igual = described_class.add_own(account, template, 'igual')
      cambio = described_class.add_own(account, template, 'cambió')
      roja = described_class.add_own(account, template, 'roja')
      fijada = described_class.add_own(account, template, 'fijada')
      igual.update!(previous_dry: { 'path' => 'a' }, last_dry: { 'path' => 'a' }, last_live: { 'cumple' => true, 'tokens' => 900 })
      cambio.update!(previous_dry: { 'path' => 'a' }, last_dry: { 'path' => 'b' })
      roja.update!(last_live: { 'cumple' => false, 'tokens' => 1100 })
      fijada.update!(pinned: true)

      candidatos = described_class.live_candidates(template)

      expect(candidatos).to eq([cambio, roja, fijada])
      # roja costó 1100; las otras dos nunca corrieron → el promedio (1000)
      expect(described_class.estimate_tokens(template, candidatos)).to eq(3100)
    end
  end

  describe '.store_live' do
    it 'deja el resultado en la prueba y el anterior como «antes»' do
      caso = described_class.add_own(account, template, '¿precio?')
      fila = { reply: 'Claro #cotizar', cumple: true, motivo: 'ok', fallas: [], ruta_ok: true, conversation: 9,
               traza: { 'camino' => 'kbase', 'uso' => { 'tokens' => 1500 } } }

      described_class.store_live(account, caso.id, fila)
      described_class.store_live(account, caso.id, fila.merge(cumple: false))

      expect(caso.reload.last_live).to include('cumple' => false, 'tokens' => 1500, 'conversation' => 9)
      expect(caso.previous_live).to include('cumple' => true)
      expect(caso.live_failed?).to be(true)
    end

    it 'no toca pruebas de otra cuenta' do
      ajena = described_class.add_own(create(:account), create(:tracking_template), 'x')

      described_class.store_live(account, ajena.id, { cumple: true })

      expect(ajena.reload.last_live).to eq({})
    end
  end

  describe 'TestBatteryScenarios.from_cases' do
    it 'lleva el id de la prueba y la etiqueta de su ruta' do
      described_class.generate(account, template)
      caso = template.test_cases.find_by(source_key: 'ruta:cotizar')

      escenario = ContactTrackings::Assistant::TestBatteryScenarios.from_cases(template, [caso.id]).first

      expect(escenario.to_h).to include(id: "caso:#{caso.id}", kind: 'ruta', route: 'cotizar', tag: 'cotizar')
    end
  end
end
