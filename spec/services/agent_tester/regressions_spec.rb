# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — cómo salió cada prueba la vez anterior (con la misma búsqueda).
RSpec.describe AgentTester::Regressions do
  let(:account) { create(:account) }
  let(:template) { create(:tracking_template, account: account) }
  let(:batch) { AgentTestBatch.create!(account: account, tracking_template: template, name: 'Lote') }

  def run(results, at:, seleccion: nil)
    batch.runs.create!(account: account, tracking_template: template, status: 'done', results: results, seleccion: seleccion,
                       created_at: at)
  end

  it 'toma el último resultado de cada prueba antes de esta corrida, solo con la misma búsqueda' do
    run([{ 'case_id' => 1, 'ok' => true }, { 'case_id' => 2, 'ok' => false }], at: 3.hours.ago)
    run([{ 'case_id' => 1, 'ok' => false }], at: 2.hours.ago)
    run([{ 'case_id' => 2, 'ok' => true }], at: 1.hour.ago, seleccion: 'on')
    actual = run([], at: Time.current)

    expect(described_class.before(actual)).to eq(1 => false, 2 => false)
  end
end
