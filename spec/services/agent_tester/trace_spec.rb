# frozen_string_literal: true

require 'rails_helper'

# proyecto@auditoria_predefinidas — en el probador, cada fragmento que es una predefinida
# dice lo que la auditoría tiene pendiente de ella y si pasa del tope de caracteres.
RSpec.describe AgentTester::Trace do
  let(:account) { create(:account) }
  let!(:formas) { create(:canned_response, account: account, short_code: 'Formas de titulación', content: 'Lista') }
  let!(:otra) { create(:canned_response, account: account, short_code: 'Licenciaturas: formas', content: 'x' * 2100) }
  let(:trace) do
    { 'engine' => '1', 'fuente' => { 'modo' => 'canned_response' },
      'fragmentos' => [{ 'titulo' => 'Formas de titulación', 'similitud' => 0.59 },
                       { 'titulo' => 'Licenciaturas: formas', 'similitud' => 0.61 },
                       { 'titulo' => 'Sin auditoría', 'similitud' => 0.4 }] }
  end

  before do
    account.canned_response_findings.create!(canned_response: formas, other_canned_response: otra, kind: 'duplicate', digest: 'x')
  end

  it 'marca hallazgos y tamaño de cada fragmento' do
    expect(described_class.lines(trace, account: account)).to eq(
      ['Fuente: canned_response',
       'Fragmento: Formas de titulación (0.59) ⚠ Auditoría: duplicada',
       'Fragmento: Licenciaturas: formas (0.61) ⚠ Auditoría: duplicada, 2123 caracteres, pasa del tope',
       'Fragmento: Sin auditoría (0.4)']
    )
  end

  it 'sin cuenta, los renglones de siempre' do
    expect(described_class.lines(trace)).to include('Fragmento: Formas de titulación (0.59)')
  end
end
