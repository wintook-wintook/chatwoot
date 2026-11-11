# frozen_string_literal: true

require 'rails_helper'

# proyecto@crear_agente_conversando §15 P2 — hojas exactas y ERP, como el motor.
RSpec.describe ContactTrackings::Assistant::SourceProbeExact do
  let(:account) { create(:account) }
  let(:probe) { described_class.new(account) }

  describe 'hojas' do
    let!(:hoja) do
      create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Precios', config: { 'sheet_mode' => 'faq' })
    end

    before do
      account.enable_features!('google_calendar')
      [%w[Camisa 250], %w[Pantalón 480], %w[Tornillo 3]].each_with_index do |(producto, precio), i|
        GoogleSheetRow.create!(account: account, knowledge_source: hoja, row_index: i,
                               data: { 'Producto' => producto, 'Precio' => precio })
      end
    end

    it 'hoja_buscar toma el «?» de la frase y dice qué fila encontró y qué regresa' do
      resultado = probe.sheet_lookup(' Precios | Producto=? | Precio', '¿cuánto cuesta el pantalon?')

      expect(resultado).to include(kind: 'sheet_lookup', status: 'ok', sheet: 'Precios', found: ['480'],
                                   rows: ['Producto: Pantalón · Precio: 480'], more: 0)
      expect(resultado[:criteria]).to eq(['Producto = Pantalón'])
    end

    it 'sin el dato en la frase, dice qué le preguntaría al cliente; sin fila, que no hay' do
      expect(probe.sheet_lookup('Precios | Producto=? | Precio', 'hola')).to include(status: 'needs_value', asked: 'Producto')
      expect(probe.sheet_lookup('Precios | Producto=Calcetín | Precio', 'x')).to include(status: 'no_match')
      expect(probe.sheet_lookup('Precios | Color=? | Precio', 'x')).to include(status: 'column_missing', missing: ['Color'])
    end

    it 'la hoja en modo datos responde lo que calcula SheetQueryService' do
      servicio = instance_double(SheetQueryService, perform: 'El total es 733')
      allow(SheetQueryService).to receive(:new).with(hoja, '¿cuánto suman?', account).and_return(servicio)

      expect(probe.sheet_data(hoja, '¿cuánto suman?')).to eq(kind: 'sheet_data', status: 'ok', answer: 'El total es 733')
    end
  end

  it 'sin Google activo, las hojas no se consultan' do
    expect(probe.sheet_lookup('Precios | Producto=? | Precio', 'x')).to eq(kind: 'sheet_lookup', error: 'google_disabled')
  end

  describe 'ERP' do
    let(:consulta) { instance_double(ExternalDbQuery, name: 'buscar_productos', params_schema: [{ 'key' => 'texto' }]) }
    let(:raw) { '{{consulta:sae/buscar_productos(linea=COMPUTO, texto=?)}}' }

    before { allow_any_instance_of(ExternalDb::ConsultaDirectiveRenderer).to receive(:resolve).and_return(consulta) } # rubocop:disable RSpec/AnyInstance

    def la_ia_llena(lleno)
      allow(ExternalDb::AskedParams).to receive(:new).and_return(instance_double(ExternalDb::AskedParams, call: lleno))
    end

    it 'con «?»: la IA llena los parámetros, corre y muestra las filas' do
      la_ia_llena(use: true, params: { 'texto' => 'hp' })
      corrida = instance_double(ExternalDb::AskedRun, call: { columns: %w[NOMBRE PRECIO], rows: [{ 'NOMBRE' => 'HP 240' }],
                                                              partial: false })
      allow(ExternalDb::AskedRun).to receive(:new).with(consulta, hash_including('texto' => 'hp', 'linea' => 'COMPUTO'))
                                                  .and_return(corrida)

      expect(probe.erp(raw, 'laptops hp')).to include(kind: 'erp', status: 'ok', columns: %w[NOMBRE PRECIO],
                                                      rows: [{ 'NOMBRE' => 'HP 240' }])
    end

    it 'si la IA dice que la frase no pide la consulta, lo dice' do
      la_ia_llena(use: false)

      expect(probe.erp(raw, 'hola')).to eq(kind: 'erp', status: 'not_asked')
    end

    it 'sin «?» es el render de siempre; una consulta que no existe lo dice' do
      allow_any_instance_of(ExternalDb::ConsultaDirectiveRenderer).to receive(:render).and_return("• HP 240\n") # rubocop:disable RSpec/AnyInstance
      expect(probe.erp('{{consulta:sae/catalogo}}', 'x')).to eq(kind: 'erp', status: 'ok', rendered: '• HP 240')

      allow_any_instance_of(ExternalDb::ConsultaDirectiveRenderer).to receive(:resolve).and_return(nil) # rubocop:disable RSpec/AnyInstance
      expect(probe.erp(raw, 'x')).to eq(kind: 'erp', error: 'query_missing')
    end
  end
end
