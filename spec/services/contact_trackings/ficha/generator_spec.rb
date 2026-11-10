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

  it 'la bienvenida va como [MENSAJE DE BIENVENIDA] con sus archivos, y el comprobador la acepta' do
    resultado = generar([{ 'key' => "google_sheet:#{hoja.id}" }], welcome: '¡Hola! Soy Sofía 👋', welcome_files: %w[catalogo])

    expect(resultado[:prompt]).to include("[MENSAJE DE BIENVENIDA]\n¡Hola! Soy Sofía 👋\n{{catalogo}}")
    expect(ContactTrackings::WelcomeMessage.text(resultado[:prompt])).to eq("¡Hola! Soy Sofía 👋\n{{catalogo}}")
    expect(resultado[:validation][:blocking]).to eq([])
  end

  it 'una hoja con «para qué» y columnas elegidas escribe su ruta con eso' do
    item = { 'key' => "google_sheet:#{hoja.id}",
             'sheet' => { 'purpose' => 'tarifas por zona', 'search_by' => 'Zona', 'answer_with' => %w[Precio Inventada] } }
    resultado = generar([item])

    ruta = '@ruta(consultar_precios #precios: pregunta por tarifas por zona): {{hoja_buscar: Precios | Zona=? | Precio}}'
    expect(resultado[:prompt]).to include(ruta)
    expect(resultado[:prompt]).to include('consultar_precios: Tarifas por zona: busco en la hoja «Precios» y contesto con Precio')
    expect(resultado[:validation][:blocking]).to eq([])
    expect(ContactTrackings::Ficha::SheetUse.clean({ 'search_by' => 'Inventada' }, %w[Zona Precio])).to be_nil
  end

  it 'un ticket con motivos y prioridad: la ruta se describe con los motivos' do
    tipo = CaseType.last
    item = { 'key' => "case_type:#{tipo.id}",
             'ticket' => { 'reasons' => ['quiere hablar con una persona', 'reporta (una) falla'], 'priority' => 'alta' } }
    resultado = generar([{ 'key' => "google_sheet:#{hoja.id}" }, item])

    expect(resultado[:prompt]).to include('quiere hablar con una persona, reporta una falla): - -> @crear_ticket(tipo=Cotización, prioridad=alta)')
    expect(resultado[:prompt]).to include('Abro un ticket «Cotización» cuando el cliente quiere hablar con una persona; reporta una falla.')
    expect(resultado[:validation][:degrading]).to eq([])
    expect(ContactTrackings::Ficha::TicketUse.clean({ 'priority' => 'altísima' })).to be_nil
  end

  it '«con la ruta X»: el alcance de esa ruta dice que mande el archivo; la regla guarda el nombre de la ruta' do
    borrador = ContactTrackings::Ficha::Draft.new(account, { name: 'Grúas', items: [{ key: "google_sheet:#{hoja.id}" }],
                                                             files: [{ name: 'lista', ask: false, routes: ["google_sheet:#{hoja.id}"] }] })

    expect(borrador.result[:prompt]).to include('consultar_precios: Busco en la hoja')
    expect(borrador.result[:prompt]).to include('Al contestar, escribo {{lista}} en mi respuesta para mandarle el archivo.')
    expect(borrador.file_rules['lista']['routes']).to eq(['consultar_precios'])
    expect(borrador.result[:validation][:blocking]).to eq([])
  end

  it 'un ticket puede levantarse cuando una fuente no encuentra la respuesta' do
    tipo = CaseType.last
    items = [{ 'key' => "google_sheet:#{hoja.id}" },
             { 'key' => "case_type:#{tipo.id}", 'ticket' => { 'reasons' => ['pide cotización'], 'escalate_from' => ["google_sheet:#{hoja.id}"] } }]
    resultado = generar(items)

    expect(resultado[:prompt]).to match(/@ruta\(consultar_precios .*\): \{\{hoja_buscar: Precios [^}]*\}\} -> @crear_ticket\(tipo=Cotización\)/)
    expect(resultado[:validation][:blocking]).to eq([])
  end
end
