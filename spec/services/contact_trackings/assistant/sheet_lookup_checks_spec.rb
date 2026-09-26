# frozen_string_literal: true

# proyecto@hoja_buscar
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::SheetLookupChecks do
  let(:account) { create(:account) }
  let!(:hoja) do
    KnowledgeSource.create!(account: account, source_type: 'google_sheet', name: 'Servicio Gruas', status: 'active')
  end

  around { |example| I18n.with_locale(:es) { example.run } }

  before do
    GoogleSheetRow.create!(account: account, knowledge_source: hoja, row_index: 0,
                           data: { 'remolque' => 'TP-64', 'Calendar_ID' => 'c64' })
  end

  def validar(directiva)
    texto = "@ruta(solicitud #solicita_servicio: quiero un servicio): {{hoja:Servicio Gruas}} -> #{directiva} -> @agendar_calendar\n" \
            "@ruta_por_defecto: solicitud\n\n[ROL]\nAgente de grúas."
    ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call
  end

  def hallazgo(resultado, codigo)
    (resultado[:blocking] + resultado[:degrading]).find { |f| f[:code] == codigo }
  end

  it 'bien escrita y contra columnas que existen, no marca nada' do
    resultado = validar('{{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}}')

    expect((resultado[:blocking] + resultado[:degrading]).pluck(:code).grep(/sheet_lookup/)).to be_empty
  end

  it 'sin una de sus tres partes la marca en rojo, en su línea y en su ruta' do
    aviso = hallazgo(validar('{{hoja_buscar: Servicio Gruas | remolque=?}}'), :sheet_lookup_invalid)

    expect(aviso).to include(line: 1, route: 'solicitud')
    expect(aviso[:message]).to include('{{hoja_buscar: Hoja | columna=valores | columna a regresar}}')
  end

  it 'una hoja que no existe' do
    aviso = hallazgo(validar('{{hoja_buscar: Gruas | remolque=? | Calendar_ID}}'), :sheet_lookup_sheet_missing)

    expect(aviso[:message]).to include("la hoja 'Gruas' no existe")
  end

  it 'una columna que la hoja no tiene, con las que sí tiene' do
    aviso = hallazgo(validar('{{hoja_buscar: Servicio Gruas | unidad=? | Calendario}}'), :sheet_lookup_column_missing)

    expect(aviso[:message]).to include('la columna unidad, Calendario').and include('remolque, Calendar_ID')
  end

  it 'una hoja sin sus filas guardadas pide sincronizarla (ámbar)' do
    hoja.google_sheet_rows.delete_all
    resultado = validar('{{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}}')

    expect(resultado[:degrading].pluck(:code)).to include(:sheet_lookup_no_rows)
  end

  it 'como fuente de una ruta, con comparación, no marca «fuente desconocida» ni «no existe»' do
    fuente = '{{hoja_buscar: Servicio Gruas | remolque=?; remolque!=TP-1 | Calendar_ID}}'
    texto = "@ruta(datos #consulta_producto: capacidad de un remolque): #{fuente}\n" \
            "@ruta_por_defecto: datos\n\n[ROL]\nAgente."
    resultado = ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call

    expect((resultado[:blocking] + resultado[:degrading]).pluck(:code))
      .not_to include(:unknown_source, :source_not_found, :sheet_lookup_invalid, :sheet_lookup_column_missing)
  end

  it 'una comparación sin número sale en rojo' do
    expect(validar('{{hoja_buscar: Servicio Gruas | remolque>=grande | Calendar_ID}}')[:blocking].pluck(:code))
      .to include(:sheet_lookup_invalid)
  end

  it 'una opción de @agendar_calendar que el motor no entiende sale en rojo (pieza 3)' do
    texto = "@ruta(agenda #consulta_producto: horarios): - -> @agendar_calendar(horario=noche)\n" \
            "@ruta_por_defecto: agenda\n\n[ROL]\nAgente."
    resultado = ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call

    expect(resultado[:blocking].find { |f| f[:code] == :calendar_option_invalid }).to include(route: 'agenda')
  end

  it 'con requiere=pago avisa si la cuenta no tiene la etiqueta pago_confirmado, con «Crearla» (pieza 4)' do
    texto = "@ruta(confirmacion #consulta_producto: le confirmamos el servicio): - -> @confirmar_servicio(requiere=pago)\n" \
            "@ruta_por_defecto: confirmacion\n\n[ROL]\nAgente."
    avisos = ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call[:degrading]
    aviso = avisos.find { |f| f[:wrote] == '#pago_confirmado' }

    expect(aviso).to include(code: :state_label_not_found, route: 'confirmacion')
  end

  describe '@solicitudes (pieza 5, F5)' do
    def codigos(accion)
      texto = "@ruta(solicitud #consulta_producto: solicito programar unidades): {{hoja:Servicio Gruas}} -> #{accion}\n" \
              "@ruta_por_defecto: solicitud\n\n[ROL]\nAgente."
      r = ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call
      (r[:blocking] + r[:degrading]).pluck(:code)
    end

    it 'sin @crear_ticket después, rojo' do
      expect(codigos('@solicitudes -> @agendar_calendar')).to include(:solicitudes_without_ticket)
    end

    it 'con agenda pero sin {{hoja_buscar:}}, ámbar' do
      expect(codigos('@solicitudes -> @crear_ticket -> @agendar_calendar')).to include(:solicitudes_without_lookup)
    end

    it 'completa, sin avisos de @solicitudes' do
      accion = '@solicitudes -> @crear_ticket -> @agendar_calendar(duracion=?) -> {{hoja_buscar: Servicio Gruas | tipo=? | Calendar_ID}}'
      expect(codigos(accion).grep(/solicitudes/)).to be_empty
    end
  end
end
