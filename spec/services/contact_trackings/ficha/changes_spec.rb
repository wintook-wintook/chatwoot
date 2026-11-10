# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — si cambia la ficha se detecta y se dice; aplicar no rompe el Entrenamiento.
RSpec.describe ContactTrackings::Ficha::Changes do
  let(:account) { create(:account) }
  let!(:hoja) { create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Precios') }
  let!(:otra) { create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Inventario') }
  let(:prompt) do
    <<~TXT.strip
      @ruta(consultar_precios #precios: pregunta por servicio, zona, precio): {{hoja:Precios}}
      @ruta_por_defecto: consultar_precios

      [ROL]
      Soy el asistente.

      [ALCANCE POR RAMA]
      consultar_precios: Busco en la hoja «Precios» el dato que pide.

      [ETIQUETAS]
      #precios = cuando el cliente pregunta por precios.
    TXT
  end
  let(:template) { create(:tracking_template, account: account, complementary_prompt: prompt) }

  before do
    [hoja, otra].each do |fuente|
      GoogleSheetRow.create!(account: account, knowledge_source: fuente, row_index: 0, data: { 'Producto' => 'X', 'Precio' => '10' })
    end
  end

  it 'sin ficha guardada la deduce del prompt y no hay cambios' do
    cambios = described_class.new(template)

    expect(cambios.items).to eq([{ 'key' => "google_sheet:#{hoja.id}" }])
    expect(cambios.call).to include(added: [], removed: [], confirmed: false)
    expect(cambios.chat_lines).to eq([])
  end

  it 'agregar y quitar recursos de la ficha se detecta y se le dice al chat' do
    template.update!(resources: { 'items' => [{ 'key' => "google_sheet:#{otra.id}" }], 'confirmed_at' => Time.current.iso8601 })
    cambios = described_class.new(template.reload)

    expect(cambios.call[:added].pluck(:name)).to eq(['Inventario'])
    expect(cambios.call[:removed]).to contain_exactly(include(name: 'Precios', route: 'consultar_precios'))
    expect(cambios.chat_lines.join("\n")).to include('Agregó «Inventario»', 'Quitó «Precios»', 'consultar_precios')
  end

  it 'aplicar agrega la ruta nueva y quita la vieja sin romper el Entrenamiento' do
    template.update!(resources: { 'items' => [{ 'key' => "google_sheet:#{otra.id}" }], 'confirmed_at' => Time.current.iso8601 })
    cambios = described_class.new(template.reload)
    oferta = ContactTrackings::Ficha::Offers.new(ContactTrackings::Ficha::Catalog.new(account, template: template).call, cambios.items)
                                            .call.first
    texto = ContactTrackings::Ficha::PromptEditor.new(prompt).add(oferta).remove('consultar_precios').text

    expect(texto).to include('@ruta(consultar_inventario', '@ruta_por_defecto: consultar_inventario', 'consultar_inventario: Busco')
    expect(texto).not_to include('consultar_precios', '#precios =')
    expect(ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call[:blocking]).to eq([])
  end

  it 'una búsqueda de predefinidas sin grupo cubre todos los grupos: no inventa cambios' do
    ['PATITAS uno', 'PATITAS dos', 'PATITAS tres', 'PATITAS cuatro'].each do |codigo|
      create(:canned_response, account: account, short_code: codigo, content: codigo)
    end
    create(:knowledge_source, account: account, source_type: 'canned_response', name: 'Respuestas')
    sin_grupo = create(:tracking_template, account: account,
                                           complementary_prompt: "@ruta(dudas #dudas: pregunta algo): @buscar_predefinidas\n")
    items = described_class.new(sin_grupo).items
    sin_grupo.update!(resources: { 'items' => items, 'confirmed_at' => Time.current.iso8601 })

    expect(items).to eq([{ 'key' => 'canned_response' }])
    expect(described_class.new(sin_grupo.reload).call).to include(added: [], removed: [])
  end

  it 'para probar: cada ruta con el recurso que usa (o sin recurso)' do
    otra = create(:tracking_template, account: account,
                                      complementary_prompt: "#{prompt}\n@ruta(urgencias #urgencia: se cayó, no respira): - -> @crear_ticket\n")
    rutas = described_class.new(otra).test_routes.index_by { |r| r[:name] }

    expect(rutas['consultar_precios']).to include(key: "google_sheet:#{hoja.id}", kind: 'sheet')
    expect(rutas['urgencias']).to include(key: nil, description: 'se cayó, no respira', label: 'Urgencias')
  end

  it 'el editor suma una frase de cliente a la descripción de una ruta, una sola vez' do
    texto = ContactTrackings::Ficha::PromptEditor.new(prompt).add_phrase('consultar_precios', '¿cuánto (aprox) cuesta?')
                                                 .add_phrase('consultar_precios', '¿cuánto aprox cuesta?').text

    expect(texto).to include('@ruta(consultar_precios #precios: pregunta por servicio, zona, precio, ¿cuánto aprox cuesta?): {{hoja:Precios}}')
    expect(texto.scan('¿cuánto aprox cuesta?').size).to eq(1)
    expect(ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call[:blocking]).to eq([])
  end

  it 'un ticket con prioridad cuenta como el mismo tipo (no inventa cambios)' do
    CaseType.create!(account: account, name: 'Soporte')
    linea = '@ruta(soporte #soporte: falla): - -> @crear_ticket(tipo=Soporte, prioridad=alta)'
    con_ticket = create(:tracking_template, account: account, complementary_prompt: "#{prompt}\n#{linea}\n")
    items = described_class.new(con_ticket).items
    expect(items).to include({ 'key' => "case_type:#{CaseType.find_by(name: 'Soporte').id}" })
  end
end
