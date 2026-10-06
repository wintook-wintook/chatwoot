# frozen_string_literal: true

require 'rails_helper'

# proyecto@erp_productos — F2: la IA llena los "?" (docs/erp_productos_plan.md §3.2).
RSpec.describe ExternalDb::AskedConsulta do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:connection) do
    ExternalDbConnection.create!(account: account, name: 'SAE', engine: :firebird, erp_type: :sae, host: 'erp.test',
                                 port: 3050, database: 'db', company_suffix: '01')
  end
  let!(:query) do
    connection.external_db_queries.create!(account: account, name: 'buscar_productos', description: 'Busca productos',
                                           sql_template: 'SELECT CODIGO FROM INVE01 WHERE :texto_1 IS NULL',
                                           params_schema: ExternalDb::QueryLibrary::PRODUCT_PARAMS)
  end
  let(:runner) { instance_double(ExternalDb::QueryRunner) }
  let(:rows) { Array.new(12) { |i| { 'CODIGO' => "P#{i}" } } }

  before do
    create(:integrations_hook, :openai, account: account)
    allow(ExternalDb::QueryRunner).to receive(:new).and_return(runner)
    allow(runner).to receive(:perform).and_return(
      ExternalDb::QueryRunner::Result.new(columns: ['CODIGO'], rows: rows, row_count: 12, duration_ms: 1)
    )
  end

  def ai_answers(json)
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: 200, body: { choices: [{ message: { content: json.to_json } }] }.to_json)
  end

  def call(source, question = '¿tienen laptops hp de menos de 15 mil?')
    described_class.new(source: source, question: question, conversation: conversation).call
  end

  it 'la IA llena solo los "?"; los fijos ganan y no se los muestra' do
    ai_answers(usar: true, parametros: { texto: 'laptop hp', precio_max: '15000', linea: 'OTRA', lista: '9' })

    data = call('{{consulta:sae/buscar_productos(linea=COMPUTO, texto=?, precio_max=?)}}')

    expect(ExternalDb::QueryRunner).to have_received(:new)
      .with(query, { 'texto' => 'laptop hp', 'precio_max' => '15000', 'linea' => 'COMPUTO' })
    expect(data[:query]).to eq(query)
    expect(a_request(:post, %r{chat/completions}).with { |r| r.body.exclude?('COMPUTO') }).to have_been_made
  end

  it 'recorta a max (5 por defecto, tope 10)' do
    ai_answers(usar: true, parametros: { texto: 'x' })

    expect(call('{{consulta:sae/buscar_productos(texto=?)}}')[:rows].size).to eq(5)
    expect(call('{{consulta:sae/buscar_productos(texto=?, max=50)}}')[:rows].size).to eq(10)
  end

  it 'si el mensaje no pide la consulta, no la corre' do
    ai_answers(usar: false, parametros: {})

    expect(call('{{consulta:sae/buscar_productos(texto=?)}}', 'gracias')).to be_nil
    expect(ExternalDb::QueryRunner).not_to have_received(:new)
  end

  it 'sin respuesta usable de la IA, o sin la consulta, no inventa: nil' do
    stub_request(:post, %r{chat/completions}).to_return(status: 500, body: '{}')

    expect(call('{{consulta:sae/buscar_productos(texto=?)}}')).to be_nil
    expect(call('{{consulta:sae/no_existe(texto=?)}}')).to be_nil
  end

  describe 'sin resultados con todas las palabras' do
    let(:toshiba) { { 'CODIGO' => 'BOL-0014', 'NOMBRE' => 'AIERE ACONDICIONADO TOSHIBA' } }
    let(:aires) { Array.new(4) { |i| { 'CODIGO' => "A#{i}", 'NOMBRE' => "AIRE ACONDICIONADO #{i}" } } }

    def result(found)
      ExternalDb::QueryRunner::Result.new(columns: %w[CODIGO NOMBRE], rows: found, row_count: found.size, duration_ms: 1)
    end

    it 'busca por palabra, pone primero la más específica y lo marca como parcial' do
      ai_answers(usar: true, parametros: { texto: 'aire acondicionado toshiba' })
      allow(runner).to receive(:perform).and_return(result([]), result(aires), result(aires + [toshiba]), result([toshiba]))

      data = call('{{consulta:sae/buscar_productos(texto=?)}}')

      expect(data[:partial]).to be(true)
      expect(data[:rows].first).to eq(toshiba)
      expect(data[:rows].size).to eq(5)
    end

    it 'con una sola palabra no hay búsqueda parcial' do
      ai_answers(usar: true, parametros: { texto: 'toshiba' })
      allow(runner).to receive(:perform).and_return(result([]))

      expect(call('{{consulta:sae/buscar_productos(texto=?)}}')).to include(rows: [], partial: false)
      expect(runner).to have_received(:perform).once
    end
  end
end
