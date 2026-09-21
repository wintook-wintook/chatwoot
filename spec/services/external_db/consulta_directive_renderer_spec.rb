# frozen_string_literal: true

require 'rails_helper'

# proyecto@erp_productos — F1: parámetros "?" en {{consulta:}} (docs/erp_productos_plan.md §3).
RSpec.describe ExternalDb::ConsultaDirectiveRenderer do
  let(:account) { create(:account) }
  let(:connection) do
    ExternalDbConnection.create!(account: account, name: 'SAE Servicios', engine: :firebird, erp_type: :sae,
                                 host: 'erp.test', port: 3050, database: 'db', company_suffix: '01')
  end
  let!(:saldo) do
    connection.external_db_queries.create!(account: account, name: 'saldo_cliente', result_format: :summary,
                                           sql_template: 'SELECT SALDO FROM CLIE01 WHERE RFC = :rfc',
                                           params_schema: [{ 'key' => 'rfc', 'type' => 'string', 'required' => true }])
  end
  let(:contact) { create(:contact, account: account, custom_attributes: { 'erp_rfc' => 'XAXX010101000' }) }
  let(:renderer) { described_class.new(account: account, contact: contact) }

  describe '.parse' do
    it 'separa los valores fijos de los que pide a la IA' do
      directive = described_class.parse(
        'Mira: {{consulta:sae/buscar_productos(linea=COMPUTO, texto=?, precio_max=?)}} y listo'
      ).first

      expect(directive.to_h).to include(conn: 'sae', name: 'buscar_productos', fixed: { 'linea' => 'COMPUTO' },
                                        asked: %w[texto precio_max], positional: nil)
      expect(directive).to be_asks
    end

    it 'lee también las de siempre: sin argumentos, posicional y varias en un texto' do
      directives = described_class.parse('{{consulta:saldo_cliente}} {{consulta:saldo_cliente(XAXX)}}')

      expect(directives.map(&:asks?)).to eq([false, false])
      expect(directives.last.positional).to eq('XAXX')
      expect(described_class.asks?('{{consulta:saldo_cliente}}')).to be(false)
      expect(described_class.asks?('{{consulta:buscar_productos(texto=?)}}')).to be(true)
    end
  end

  describe '#render (el camino de siempre)' do
    let(:runner) { instance_double(ExternalDb::QueryRunner) }

    before do
      allow(ExternalDb::QueryRunner).to receive(:new).and_return(runner)
      allow(runner).to receive(:perform).and_return(
        ExternalDb::QueryRunner::Result.new(columns: ['SALDO'], rows: [{ 'SALDO' => 3480.0 }], row_count: 1, duration_ms: 1)
      )
    end

    it 'sin "?" interpola igual que antes, con el RFC del contacto' do
      expect(renderer.render('Tu saldo es {{consulta:sae/saldo_cliente}}')).to eq('Tu saldo es 3480.00')
      expect(ExternalDb::QueryRunner).to have_received(:new).with(saldo, 'rfc' => 'XAXX010101000')
    end

    it 'un "?" nunca viaja como valor a la consulta' do
      renderer.render('{{consulta:sae/saldo_cliente(rfc=?)}}')

      expect(ExternalDb::QueryRunner).to have_received(:new).with(saldo, 'rfc' => 'XAXX010101000')
    end
  end

  describe '#resolve' do
    it 'encuentra la consulta con las mismas reglas de conexión que el render' do
      directive = described_class.parse('{{consulta:sae/SALDO_CLIENTE(rfc=?)}}').first

      expect(renderer.resolve(directive)).to eq(saldo)
      expect(renderer.resolve(described_class.parse('{{consulta:microsip/saldo_cliente}}').first)).to be_nil
    end
  end
end
