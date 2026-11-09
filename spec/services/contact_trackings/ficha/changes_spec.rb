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
end
