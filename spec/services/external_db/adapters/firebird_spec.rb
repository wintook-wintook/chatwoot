# frozen_string_literal: true

require 'rails_helper'

# proyecto@erp_productos — la codificación de Firebird (docs/erp_productos_plan.md, F0).
RSpec.describe ExternalDb::Adapters::Firebird do
  let(:account) { create(:account) }
  let(:conn) do
    ExternalDbConnection.create!(account: account, name: 'sae', engine: :firebird, erp_type: :sae, host: 'erp.test',
                                 port: 3050, database: 'db', options: options)
  end
  let(:options) { {} }
  let(:fb) { double('Fb::Connection') } # rubocop:disable RSpec/VerifiedDoubles
  let(:adapter) { described_class.new(conn) }

  before { allow(adapter).to receive(:connection).and_return(fb) }

  it 'con charset NONE lee en Windows-1252 los textos que no son UTF-8 y manda así los parámetros' do
    allow(fb).to receive(:query) { |_mode, _sql, *binds|
      expect(binds.first.encoding).to eq(Encoding::Windows_1252)
      [{ 'NOMBRE' => (+"Precio p\xFAblico").force_encoding(Encoding::BINARY), 'N' => 3, 'OK' => 'ya utf-8 ñ' }]
    }

    row = adapter.select('SELECT …', ['cañón']).first
    expect(row['NOMBRE']).to eq('Precio público')
    expect(row['OK']).to eq('ya utf-8 ñ')
    expect(row['N']).to eq(3)
  end

  context 'with a declared charset (no convierte)' do
    let(:options) { { 'charset' => 'UTF8' } }

    it 'no convierte nada' do
      allow(fb).to receive(:query).and_return([{ 'NOMBRE' => 'tal cual' }])

      expect(adapter.select('SELECT …', ['cañón'])).to eq([{ 'NOMBRE' => 'tal cual' }])
      expect(fb).to have_received(:query).with(:hash, 'SELECT …', 'cañón')
    end
  end
end
