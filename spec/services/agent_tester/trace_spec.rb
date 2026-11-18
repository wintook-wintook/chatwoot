# frozen_string_literal: true

require 'rails_helper'

# proyecto@auditoria_predefinidas — en el probador, cada fragmento que es una predefinida
# dice lo que la auditoría tiene pendiente de ella y si pasa del tope de caracteres.
RSpec.describe AgentTester::Trace do
  let(:account) { create(:account) }
  let!(:formas) { create(:canned_response, account: account, short_code: 'Formas de titulación', content: 'Lista') }
  # proyecto@predefinidas_que_contestan: ya no se deja guardar una de más de 3,500; esta es
  # una vieja que pasaba el tope (escrita directo en la base).
  let!(:otra) do
    create(:canned_response, account: account, short_code: 'Licenciaturas: formas', content: 'x')
      .tap { |c| c.update_column(:content, 'x' * 3600) } # rubocop:disable Rails/SkipsModelValidations
  end
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
       'Fragmento: Licenciaturas: formas (0.61) ⚠ Auditoría: duplicada, 3623 caracteres, pasa del tope',
       'Fragmento: Sin auditoría (0.4)']
    )
  end

  it 'sin cuenta, los renglones de siempre' do
    expect(described_class.lines(trace)).to include('Fragmento: Formas de titulación (0.59)')
  end

  # proyecto@predefinidas_que_contestan
  it 'enseña qué escogió la selección y los datos que se quitaron' do
    traza = { 'engine' => '1',
              'seleccion' => { 'candidatas' => 18, 'sujeto' => ['Plan Empresarial'], 'ninguna' => false,
                               'escogidas' => [{ 'titulo' => 'Plan Empresarial — Precio', 'tipo' => 'ficha',
                                                 'por_que' => 'trae la promoción' }] },
              'datos_quitados' => { 'inventados' => ['52%'], 'quedaron' => ['52%'] } }
    expect(described_class.lines(traza)).to eq(
      ['Selección: 1 de 18 candidatas · sujeto: Plan Empresarial',
       'Escogió [ficha] Plan Empresarial — Precio — trae la promoción',
       'Datos que no estaban en las fuentes: 52% (se quitaron)']
    )
  end
end
