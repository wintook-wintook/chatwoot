# frozen_string_literal: true

require 'rails_helper'

# proyecto@erp_productos — F0 (docs/erp_productos_plan.md §3.3): `buscar_productos` y lo que
# necesitó del QueryRunner y del adaptador de Firebird. Sin ERP real: el adaptador es un
# doble que registra el SQL y los binds que recibe.
RSpec.describe ExternalDb::QueryRunner do
  let(:account) { create(:account) }
  let(:adapter) { instance_double(ExternalDb::Adapters::Firebird, inline_binds?: false, close: nil) }
  let(:sent) { {} }

  def connection(engine, erp_type)
    ExternalDbConnection.create!(account: account, name: "#{erp_type}-#{engine}", engine: engine, erp_type: erp_type,
                                 host: 'erp.test', port: 3050, database: 'db', company_suffix: '01')
  end

  def products_query(conn)
    tpl = ExternalDb::QueryLibrary.for_connection(conn).find { |t| t['name'] == 'buscar_productos' }
    ExternalDbQuery.new(external_db_connection: conn, account: account, name: 'buscar_productos',
                        sql_template: tpl['sql_template'], params_schema: tpl['params_schema'], row_limit: 50)
  end

  before do
    allow(ExternalDb::AdapterFactory).to receive(:build).and_return(adapter)
    allow(adapter).to receive(:select) do |sql, binds|
      sent[:sql] = sql
      sent[:binds] = binds
      [{ 'CODIGO' => 'A1', 'NOMBRE' => 'Escopeta cañón corto' }]
    end
  end

  describe 'la librería' do
    it 'tiene buscar_productos para SAE, Microsip y Contpaq, con los mismos parámetros opcionales' do
      %w[sae microsip contpaq].each do |erp|
        tpl = ExternalDb::QueryLibrary.templates[erp.to_sym].find { |t| t['name'] == 'buscar_productos' }
        expect(tpl['params_schema'].pluck('key')).to eq(%w[texto codigo linea precio_min precio_max con_existencia lista max])
        expect(tpl['params_schema'].none? { |p| p['required'] }).to be(true)
      end
    end

    it 'SAE lleva el sufijo de empresa; Contpaq conserva sus comodines tras el format' do
      sae = ExternalDb::QueryLibrary.for_connection(connection(:firebird, :sae)).find { |t| t['name'] == 'buscar_productos' }
      contpaq = ExternalDb::QueryLibrary.for_connection(connection(:mssql, :contpaq))
                                        .find { |t| t['name'] == 'buscar_productos' }

      expect(sae['sql_template']).to include('FROM INVE01 i', 'PRECIO_X_PROD01')
      expect(contpaq['sql_template']).to include("LIKE '%' + :texto_1 + '%'")
    end
  end

  describe 'parámetro words' do
    it 'parte el texto en palabras sin comodines ni comillas; las que faltan van como NULL' do
      described_class.new(products_query(connection(:firebird, :sae)), 'texto' => "  laptop  h'p% ").perform

      expect(sent[:binds]).to include('laptop', 'hp')
      expect(sent[:sql]).to include('CAST(NULL AS VARCHAR(60)) IS NULL') # texto_3
      expect(sent[:binds].join).not_to include("'", '%')
    end
  end

  describe 'parámetro boolean' do
    it 'entiende sí/no' do
      query = products_query(connection(:firebird, :sae))

      described_class.new(query, 'con_existencia' => 'sí').perform
      expect(sent[:binds]).to include(1)
      expect { described_class.new(query, 'con_existencia' => 'quizá').perform }
        .to raise_error(ExternalDb::QueryRunner::ParamError, /sí o no/)
    end
  end

  # La gem `fb` no puede bindear nil a un CAST(? AS …): los filtros vacíos van como NULL.
  it 'en Firebird, un parámetro vacío se escribe NULL y no se manda como bind' do
    described_class.new(products_query(connection(:firebird, :microsip)), 'precio_max' => '1500').perform

    expect(sent[:sql]).to include('CAST(NULL AS VARCHAR(60)) IS NULL', 'CAST(? AS DOUBLE PRECISION)')
    expect(sent[:binds]).to all(be_present)
    expect(sent[:binds]).to include(1500.0)
  end
end
