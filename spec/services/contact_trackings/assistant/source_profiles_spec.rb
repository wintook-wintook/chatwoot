require 'rails_helper'

# proyecto@crear_agente_conversando FR — docs/creacion_conversacional_agentes_plan.md §12
RSpec.describe ContactTrackings::Assistant::SourceProfiles do
  subject(:perfiles) { described_class.new(account) }

  let(:account) { create(:account) }

  def hoja(nombre, filas)
    fuente = create(:knowledge_source, account: account, source_type: 'google_sheet', name: nombre)
    filas.each_with_index { |data, i| GoogleSheetRow.create!(account: account, knowledge_source: fuente, row_index: i, data: data) }
    fuente
  end

  it 'una hoja dice sus columnas, filas de ejemplo y por qué columna buscar' do
    hoja('Precios', [{ 'Precio' => '$1,800', 'Producto' => 'Plataforma', 'Zona' => 'Norte' },
                     { 'Precio' => '$950', 'Producto' => 'Arrastre', 'Zona' => 'Norte' }])
    ficha = perfiles.find('precios')
    # jsonb no guarda el orden de las columnas de la hoja: se comparan sin orden.
    expect(ficha[:que_tiene].delete_suffix(' (2 filas)').split(' · ')).to contain_exactly('Precio', 'Producto', 'Zona')
    expect(ficha[:ejemplo].first.split(' | ')).to contain_exactly('$1,800', 'Plataforma', 'Norte')
    expect(ficha[:como_se_usa]).to eq('{{hoja_buscar: Precios | Producto=? | Precio}}')
  end

  it 'las predefinidas dicen sus grupos' do
    create(:knowledge_source, account: account, source_type: 'canned_response', name: 'Respuestas predefinidas')
    %w[VEN-precio VEN-promo SOP-acceso].each { |c| create(:canned_response, account: account, short_code: c, content: 'x') }
    ficha = perfiles.find('predefinidas')
    expect(ficha[:que_tiene]).to include('3 respuestas').and include('VEN (2)')
    expect(ficha[:como_se_usa]).to eq('@buscar_predefinidas(VEN)')
  end

  it 'un tipo de caso dice qué campos pide' do
    tipo = CaseType.create!(account: account, name: 'Cotización', color: '#3b82f6')
    tipo.case_type_fields.create!(account: account, key: 'zona', label: 'Zona', required: true)
    ficha = perfiles.find('Cotización')
    expect(ficha[:que_tiene]).to eq('pide: Zona (obligatorio)')
    expect(ficha[:como_se_usa]).to eq('@crear_ticket(tipo=Cotización)')
  end

  it 'el foro dice que se consulta en vivo' do
    create(:knowledge_source, account: account, source_type: 'discourse', name: 'Foro Kontrolya')
    expect(perfiles.find('foro kontrolya')[:que_tiene]).to include('en vivo')
  end

  it 'dice qué falta en una cuenta sin fuentes' do
    expect(perfiles.call).to eq([])
    expect(perfiles.missing).to include('google_sheet', 'canned_response', 'case_type')
  end

  it 'no cuenta las fuentes apagadas' do
    hoja('Vieja', [{ 'A' => '1', 'B' => 'x' }]).update!(status: 'inactive')
    expect(perfiles.call).to eq([])
  end
end
