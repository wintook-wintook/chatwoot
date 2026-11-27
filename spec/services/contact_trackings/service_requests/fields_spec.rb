require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Fields do
  let(:account) { create(:account) }
  let(:case_type) { CaseType.create!(account: account, name: 'Renta Unidades', color: '#3b82f6') }
  let(:extractor) { instance_double(Cases::Ai::FieldExtractor, available?: true) }

  before do
    CaseTypeField.create!(account: account, case_type: case_type, key: 'material', label: 'Material', field_type: 'text', required: true)
    CaseTypeField.create!(account: account, case_type: case_type, key: 'peso', label: 'Peso', field_type: 'text', required: true, position: 1)
    CaseTypeField.create!(account: account, case_type: case_type, key: 'medidas', label: 'Medidas de la pieza mayor', field_type: 'text',
                          required: true, position: 2)
    CaseTypeField.create!(account: account, case_type: case_type, key: 'fecha', label: 'Fecha', field_type: 'date', required: true, position: 3)
    allow(Cases::Ai::FieldExtractor).to receive(:new).and_return(extractor)
    allow(extractor).to receive(:extract).and_return('values' => { 'material' => 'tubería' })
  end

  def campos(unknown_pending:)
    described_class.new(account: account, case_type_id: case_type.id, unknown_pending: unknown_pending)
  end

  def llamar(texto, unknown_pending: true, asked: %w[peso medidas fecha])
    campos(unknown_pending: unknown_pending).call(service_text: 'Carga: tubería', message_text: texto, asked: asked, customer_text: texto)
  end

  it 'sin la opción, «no sé» no cambia nada: se sigue pidiendo (como siempre)' do
    resultado = llamar('No sé el peso exacto ni las medidas', unknown_pending: false)

    expect(resultado.missing).to eq(%w[peso medidas fecha])
  end

  it 'con sin_dato=pendiente, el dato pedido que dice no saber queda pendiente y ya no se pide' do
    resultado = llamar('No sé el peso exacto ni las medidas')

    expect(resultado.found.slice('peso', 'medidas')).to eq('peso' => described_class::PENDING_VALUE, 'medidas' => described_class::PENDING_VALUE)
    expect(resultado.missing).to eq(%w[fecha])
  end

  it 'solo el que nombra; la fecha nunca queda pendiente' do
    resultado = llamar('las medidas no las tengo, ni la fecha')

    expect(resultado.missing).to eq(%w[peso fecha])
  end

  it 'si solo se le pidió un dato, basta con «no lo sé»' do
    resultado = llamar('no lo sé', asked: %w[peso])

    expect(resultado.found['peso']).to eq(described_class::PENDING_VALUE)
  end

  it 'un dato que no se le pidió no se marca, y sin decir que no sabe tampoco' do
    expect(llamar('no sé el peso', asked: %w[medidas]).missing).to include('peso')
    expect(llamar('el peso luego te lo paso').missing).to include('peso')
  end
end
