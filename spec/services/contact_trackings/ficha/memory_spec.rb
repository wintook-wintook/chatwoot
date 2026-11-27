# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — variables por condición y las que recuerdan una columna de hoja.
RSpec.describe ContactTrackings::Ficha::Memory do
  let(:account) { create(:account) }
  let(:base) do
    <<~TXT.strip
      @ruta(precios #precios: pregunta precios): {{hoja_buscar: Precios | Carrera=? | Precio}}

      [ALCANCE POR RAMA]
      precios: Contesto con la hoja. Si ya compró, marca ETAPA=CLIENTE.

      [VARIABLES]
      ETAPA = NUEVO | CLIENTE
      Inicial: ETAPA=NUEVO
    TXT
  end
  let(:variables) do
    described_class.clean([{ 'name' => 'liga entregada', 'values' => %w[NO SÍ], 'initial' => 'NO',
                             'rules' => [{ 'to' => 'SÍ', 'when' => 'le mande la liga para agendar.' }, { 'to' => 'X', 'when' => 'nunca' }] },
                           { 'name' => 'nombre', 'free' => true, 'values' => [], 'rules' => [{ 'to' => '*', 'when' => 'diga su nombre' }] },
                           { 'name' => 'vacia', 'values' => [] }])
  end
  let(:hojas) { [{ 'name' => 'CARRERA', 'column' => 'Carrera', 'sheet' => 'Precios' }] }
  # Como la pantalla: las que ya estaban (ETAPA, escrita a mano) se reenvían al guardar.
  let(:etapa) { described_class.clean(described_class.new(base).read[:variables]) }
  let(:todas) { etapa + variables }

  it 'limpia: nombre válido, valores sin repetir, inicial válido y reglas solo a valores de su lista' do
    expect(variables).to eq([
                              { 'name' => 'LIGA_ENTREGADA', 'values' => %w[NO SÍ], 'free' => false, 'initial' => 'NO',
                                'rules' => [{ 'to' => 'SÍ', 'when' => 'le mande la liga para agendar' }] },
                              { 'name' => 'NOMBRE', 'values' => ['VACÍO'], 'free' => true, 'initial' => 'VACÍO',
                                'rules' => [{ 'to' => '*', 'when' => 'diga su nombre' }] }
                            ])
  end

  it 'lee la escrita a mano como «por condición» (sin reglas propias)' do
    expect(etapa).to eq([{ 'name' => 'ETAPA', 'values' => %w[NUEVO CLIENTE], 'free' => false, 'initial' => 'NUEVO', 'rules' => [] }])
  end

  it 'escribe declaración, inicial y regla; se lee igual; las reglas a mano se quedan' do
    texto = described_class.new(base).write(todas, hojas).text

    expect(texto).to include('ETAPA = NUEVO | CLIENTE', 'Si ya compró, marca ETAPA=CLIENTE.',
                             'LIGA_ENTREGADA = NO | SÍ', 'NOMBRE = VACÍO | valor', 'CARRERA = VACÍO | valor',
                             'Inicial: ETAPA=NUEVO; LIGA_ENTREGADA=NO; NOMBRE=VACÍO; CARRERA=VACÍO',
                             '- Marca LIGA_ENTREGADA=SÍ cuando le mande la liga para agendar.',
                             '- Guarda en NOMBRE lo que diga el cliente cuando diga su nombre.',
                             '- CARRERA guarda lo que el cliente eligió de «Carrera» en la hoja «Precios»')
    lectura = described_class.new(texto).read
    expect(lectura[:sheets]).to eq(hojas)
    expect(described_class.clean(lectura[:variables]).pluck('name')).to eq(%w[ETAPA LIGA_ENTREGADA NOMBRE])
    expect(described_class.clean(lectura[:variables])).to eq(todas)

    definicion = ContactTrackings::ConversationVariables::Definition.parse(texto)
    expect(definicion.initial).to include('CARRERA' => 'VACÍO', 'LIGA_ENTREGADA' => 'NO')
    hallazgos = ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call
    # La hoja «Precios» no existe en la cuenta de prueba: ese aviso no es de las variables.
    expect(hallazgos[:blocking].pluck(:code) - [:sheet_lookup_sheet_missing]).to eq([])
    expect(hallazgos[:degrading].pluck(:code)).not_to include(:variable_unused, :variable_value_unknown)
  end

  it 'reescribir no duplica y quitar deja solo lo ajeno' do
    texto = described_class.new(base).write(todas, hojas).text
    otra = described_class.new(texto).write(todas, hojas).text
    expect(otra.scan('LIGA_ENTREGADA = NO').size).to eq(1)

    sin = described_class.new(otra).write(etapa, []).text
    expect(sin).to include('ETAPA = NUEVO | CLIENTE', 'Inicial: ETAPA=NUEVO')
    expect(sin).not_to include('LIGA_ENTREGADA', 'CARRERA', 'CUÁNDO CAMBIAN')
  end

  it 'la variable de una columna sale de su nombre (o no hay si no da un nombre válido)' do
    expect(described_class.sheet_var('Carrera')).to eq('CARRERA')
    expect(described_class.sheet_var('Nombre carrera')).to eq('NOMBRE_CARRERA')
    expect(described_class.sheet_var('Precio $')).to be_nil
  end
end
