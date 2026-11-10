# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — probar antes de crear (clasificador simulado: no gasta).
RSpec.describe ContactTrackings::Ficha::Tester do
  let(:account) { create(:account) }
  let!(:hoja) { create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Precios') }
  let(:classifier) { instance_double(ContactTrackings::Assistant::DraftClassifier) }

  before do
    GoogleSheetRow.create!(account: account, knowledge_source: hoja, row_index: 0, data: { 'Servicio' => 'Plataforma', 'Precio' => '1800' })
    GoogleSheetRow.create!(account: account, knowledge_source: hoja, row_index: 1, data: { 'Servicio' => 'Arrastre', 'Precio' => '900' })
    CaseType.create!(account: account, name: 'Cotización')
    allow(ContactTrackings::Assistant::DraftClassifier).to receive(:new).and_return(classifier)
    allow_any_instance_of(ContactTrackings::Assistant::InventoryService).to receive(:call).and_return(customer_phrases: ['¿a qué hora abren?']) # rubocop:disable RSpec/AnyInstance
  end

  def armar(phrases: {})
    ContactTrackings::Ficha::Draft.new(account, { name: 'Grúas', phrases: phrases,
                                                  items: [{ key: "google_sheet:#{hoja.id}" }, { key: "case_type:#{CaseType.last.id}" }] })
  end

  it 'arma frases con el contenido de cada recurso y las pasa por el clasificador' do
    borrador = armar
    rutas = borrador.result[:routes]
    allow(classifier).to receive(:classify) do |frase|
      Struct.new(:name).new(frase.include?('precio') ? rutas.first[:name] : rutas.last[:name])
    end

    progreso = []
    salida = described_class.new(account, draft: borrador.result[:prompt], routes: rutas, offers: borrador.active_offers)
                            .call(progress: ->(h, t) { progreso << [h, t] })

    hoja_ruta = salida[:per_route].find { |r| r[:key] == "google_sheet:#{hoja.id}" }
    expect(hoja_ruta[:results].pluck(:phrase)).to eq(['¿Cuál es el precio de Plataforma?', '¿Cuál es el precio de Arrastre?'])
    expect(salida).to include(total: 4, passed: 4, default_route: rutas.first[:name])
    expect(salida[:real]).to eq([{ phrase: '¿a qué hora abren?', got: rutas.last[:name], got_label: rutas.last[:label], fallback: false }])
    expect(progreso.last).to eq([5, 5])
  end

  it 'las frases agregadas a una ruta se suman a su descripción' do
    borrador = armar(phrases: { "google_sheet:#{hoja.id}" => ['¿a qué hora abren?'] })
    expect(borrador.result[:prompt]).to match(/@ruta\(consultar_precios #precios: pregunta por .*, ¿a qué hora abren\?\)/)
    expect(borrador.result[:validation][:valid]).to be(true)
  end
end
