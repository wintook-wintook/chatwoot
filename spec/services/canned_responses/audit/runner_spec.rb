# frozen_string_literal: true

require 'rails_helper'

# proyecto@auditoria_predefinidas — correr la auditoría (la IA, simulada).
RSpec.describe CannedResponses::Audit::Runner do
  let(:account) { create(:account) }
  let(:neighbors) { instance_double(CannedResponses::Audit::Neighbors) }
  let(:reviewer) { instance_double(CannedResponses::Audit::Reviewer, last_error_code: nil) }
  let!(:precio_a) { create(:canned_response, account: account, short_code: 'Precio Derecho', content: 'Cuesta $1,500 al mes.') }
  let!(:precio_b) { create(:canned_response, account: account, short_code: 'Costo Derecho', content: 'La colegiatura es de $1,800.') }
  let!(:horario) { create(:canned_response, account: account, short_code: 'Horario', content: 'Abrimos de 9 a 18 h.') }

  let(:contradiccion) do
    { 'relation' => 'overlap', 'reason' => 'Las dos dan el precio de Derecho', 'suggestion' => 'Unirlas',
      'contradictions' => [{ 'topic' => 'precio', 'quote_a' => 'Cuesta $1,500 al mes.',
                             'quote_b' => 'La colegiatura es de $1,800.', 'why' => 'dos precios' }] }
  end

  before do
    create(:integrations_hook, :openai, account: account)
    allow(CannedResponses::Audit::Neighbors).to receive(:new).and_return(neighbors)
    allow(CannedResponses::Audit::Reviewer).to receive(:new).and_return(reviewer)
    allow(reviewer).to receive(:writing) { |lote| lote.to_h { |r| [r.id, []] } }
  end

  def kinds = account.canned_response_findings.unresolved.order(:kind).pluck(:kind)

  it 'guarda la contradicción y el solapamiento del par, con el id menor primero' do
    allow(neighbors).to receive(:all).and_return([[precio_a.id, precio_b.id, 0.83]])
    allow(reviewer).to receive(:pair).and_return(contradiccion)

    stats = described_class.new(account).all

    expect(kinds).to eq(%w[contradiction overlap])
    hallazgo = account.canned_response_findings.find_by(kind: 'contradiction')
    expect(hallazgo.canned_response_id).to eq(precio_a.id)
    expect(hallazgo.details['contradictions'].first['quote_b']).to eq('La colegiatura es de $1,800.')
    expect(stats).to include('responses' => 3, 'pairs' => 1, 'failed_calls' => 0)
  end

  it 'desde 0.95 es duplicada aunque la llamada a la IA falle' do
    allow(neighbors).to receive(:all).and_return([[precio_a.id, precio_b.id, 0.97]])
    allow(reviewer).to receive(:pair).and_return(nil)

    stats = described_class.new(account).all

    expect(kinds).to eq(%w[duplicate])
    expect(stats['failed_calls']).to eq(1)
  end

  it 'marca la redacción y le pone gravedad según el tipo' do
    allow(neighbors).to receive(:all).and_return([])
    allow(reviewer).to receive(:writing).and_return(
      horario.id => [{ 'type' => 'incompleta', 'quote' => 'de 9 a 18 h', 'suggestion' => 'decir qué días' }]
    )

    described_class.new(account).all

    hallazgo = account.canned_response_findings.sole
    expect([hallazgo.kind, hallazgo.severity, hallazgo.canned_response_id]).to eq(['writing', 'high', horario.id])
  end

  it 'un descartado no se vuelve a abrir mientras el texto no cambie' do
    allow(neighbors).to receive(:all).and_return([[precio_a.id, precio_b.id, 0.83]])
    allow(reviewer).to receive(:pair).and_return(contradiccion)
    described_class.new(account).all
    account.canned_response_findings.where(kind: 'contradiction').update_all(status: 'dismissed') # rubocop:disable Rails/SkipsModelValidations

    described_class.new(account).all
    expect(kinds).to eq(%w[overlap])

    precio_b.update_columns(content: 'La colegiatura es de $2,000.') # rubocop:disable Rails/SkipsModelValidations
    contradiccion['contradictions'].first['quote_b'] = 'La colegiatura es de $2,000.'
    described_class.new(account).all
    expect(kinds).to eq(%w[contradiction overlap])
  end

  it 'si la revisión falla, conserva lo que había encontrado la corrida anterior' do
    allow(neighbors).to receive(:all).and_return([[precio_a.id, precio_b.id, 0.83]])
    allow(reviewer).to receive(:pair).and_return(contradiccion)
    described_class.new(account).all

    allow(reviewer).to receive_messages(pair: nil, writing: nil, last_error_code: 'no_credits')
    stats = described_class.new(account).all

    expect(kinds).to eq(%w[contradiction overlap])
    expect(stats['error']).to eq('no_credits')
  end

  it 'quita los hallazgos de pares que ya no son vecinos' do
    allow(neighbors).to receive(:all).and_return([[precio_a.id, precio_b.id, 0.83]])
    allow(reviewer).to receive(:pair).and_return(contradiccion)
    described_class.new(account).all

    allow(neighbors).to receive(:all).and_return([])
    described_class.new(account).all

    expect(kinds).to eq([])
  end

  it 'una sola predefinida: solo toca sus hallazgos' do
    ajeno = account.canned_response_findings.create!(canned_response: horario, kind: 'writing', digest: 'x',
                                                     details: { 'issues' => [] })
    allow(neighbors).to receive(:of).with(precio_a.id).and_return([[precio_a.id, precio_b.id, 0.83]])
    allow(reviewer).to receive(:pair).and_return(contradiccion)

    described_class.new(account).one(precio_a)

    expect(kinds).to eq(%w[contradiction overlap writing])
    expect(ajeno.reload).to be_present
  end

  it 'sin integración de OpenAI no corre' do
    account.hooks.destroy_all

    expect { described_class.new(account).all }.to raise_error(described_class::NoKeyError)
  end

  it 'entre partes de una misma división aceptada no marca «se solapan», pero sí contradicciones' do
    account.canned_response_fixes.create!(kind: 'oversize', status: 'applied', source_ids: [],
                                          result: { 'created_ids' => [precio_a.id, precio_b.id] })
    allow(neighbors).to receive(:all).and_return([[precio_a.id, precio_b.id, 0.83]])
    allow(reviewer).to receive(:pair).and_return(contradiccion)

    described_class.new(account).all

    expect(kinds).to eq(%w[contradiction])
  end

  it 'casi iguales pero de sujetos distintos no son duplicadas' do
    allow(neighbors).to receive(:all).and_return([[precio_a.id, precio_b.id, 0.97]])
    allow(reviewer).to receive(:pair).and_return('relation' => 'distinct', 'same_subject' => false, 'contradictions' => [])

    described_class.new(account).all

    expect(kinds).to eq([])
  end
end
