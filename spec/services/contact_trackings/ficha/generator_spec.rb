# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — de la ficha al Entrenamiento, sin IA y sin errores del comprobador.
RSpec.describe ContactTrackings::Ficha::Generator do
  let(:account) { create(:account) }
  let!(:hoja) { create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Precios') }
  let(:cards) { ContactTrackings::Ficha::Catalog.new(account).call }

  before do
    [%w[Plataforma Norte 1800], %w[Arrastre Sur 900]].each_with_index do |(servicio, zona, precio), i|
      GoogleSheetRow.create!(account: account, knowledge_source: hoja, row_index: i,
                             data: { 'Servicio' => servicio, 'Zona' => zona, 'Precio' => precio })
    end
    CaseType.create!(account: account, name: 'Cotización')
    create(:knowledge_source, account: account, source_type: 'canned_response', name: 'Respuestas')
    ['PATITAS precio', 'PATITAS vacunas', 'PATITAS horario', 'PATITAS requisitos', 'HORARIO oficina'].each do |codigo|
      create(:canned_response, account: account, short_code: codigo, content: "Texto de #{codigo}")
    end
  end

  def generar(items, **opciones)
    ofertas = ContactTrackings::Ficha::Offers.new(cards, items).call
    described_class.new(account: account, name: 'Grúas Norte', offers: ofertas, **opciones).call
  end

  it 'el catálogo trae cada recurso con su estado y lo que puede hacer' do
    hoja_card = cards.find { |c| c[:key] == "google_sheet:#{hoja.id}" }

    expect(hoja_card).to include(kind: 'sheet', status: 'ready')
    expect(hoja_card[:offer][:directive]).to start_with('{{hoja_buscar: Precios |')
    expect(cards.find { |c| c[:kind] == 'canned' }[:parts].pluck(:label)).to include('PATITAS', 'HORARIO')
    expect(cards.find { |c| c[:kind] == 'case_type' }[:offer][:directive]).to eq('@crear_ticket(tipo=Cotización)')
  end

  it 'arma un Entrenamiento completo que el comprobador acepta sin hallazgos' do
    resultado = generar([{ 'key' => "google_sheet:#{hoja.id}" }, { 'key' => 'canned_response' },
                         { 'key' => "case_type:#{CaseType.last.id}" }])

    expect(resultado[:validation][:blocking]).to eq([])
    expect(resultado[:validation][:degrading]).to eq([])
    expect(resultado[:prompt]).to include('[ROL]', '[ALCANCE POR RAMA]', '[ETIQUETAS]', '[ESTILO]', '[PROHIBIDO]')
    expect(resultado[:prompt]).to include('@buscar_predefinidas(PATITAS)', '- -> @crear_ticket(tipo=Cotización)')
    expect(resultado[:prompt]).to match(/^@ruta_por_defecto: consultar_precios$/)
    expect(resultado[:objective]).to include('Grúas Norte')
  end

  it 'los grupos chicos de predefinidas van juntos en una ruta sin grupo' do
    resultado = generar([{ 'key' => 'canned_response', 'parts' => %w[HORARIO] }])

    expect(resultado[:prompt]).to include('@ruta(dudas_generales #generales:')
    expect(resultado[:prompt]).not_to include('@buscar_predefinidas(HORARIO)')
  end

  it 'respeta el objetivo, el tono y los datos del negocio' do
    resultado = generar([{ 'key' => "google_sheet:#{hoja.id}" }], objective: 'Cotizar grúas', tone: 'profesional',
                                                                  business: "Horario: 9 a 6\nTel 555")

    expect(resultado[:objective]).to eq('Cotizar grúas')
    expect(resultado[:prompt]).to include('sin emojis')
    expect(resultado[:ai_context]).to eq("Horario: 9 a 6\nTel 555")
  end
end
