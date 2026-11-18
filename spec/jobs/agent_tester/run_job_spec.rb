# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — la corrida va de una prueba a la vez y se vuelve a encolar.
RSpec.describe AgentTester::RunJob do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:template) { create(:tracking_template, account: account) }
  let(:batch) { AgentTestBatch.create!(account: account, tracking_template: template, name: 'Lote') }
  let!(:first) { batch.cases.create!(account: account, name: 'Uno', messages: ['Hola'], expected: 'Saluda') }
  let!(:second) { batch.cases.create!(account: account, name: 'Dos', messages: ['Precio'], expected: 'Da el precio') }
  let(:run) { batch.runs.create!(account: account, tracking_template: template, total: 2) }
  let(:runner) { instance_double(AgentTester::ConversationRunner) }

  before { allow(AgentTester::ConversationRunner).to receive(:new).and_return(runner) }

  def ok(test_case) = { case_id: test_case.id, name: test_case.name, ok: true, reply: 'listo', reason: 'Cumple.' }

  it 'corre una prueba, la guarda y se vuelve a encolar; al final queda terminada' do
    allow(runner).to receive(:run) { |c| ok(c) }

    expect { described_class.perform_now(run.id) }.to have_enqueued_job(described_class).with(run.id)
    expect(run.reload).to have_attributes(status: 'running', passed: 1)
    expect(run.case_done_ids).to eq([first.id])

    perform_enqueued_jobs { described_class.perform_now(run.id) }
    expect(run.reload).to have_attributes(status: 'done', passed: 2, total: 2)
    expect(run.finished_at).to be_present
  end

  it 'un error en una prueba queda como resultado de esa prueba y las demás siguen' do
    allow(runner).to receive(:run).with(first).and_raise(ActiveRecord::RecordInvalid)
    allow(runner).to receive(:run).with(second) { |c| ok(c) }

    perform_enqueued_jobs { described_class.perform_now(run.id) }
    run.reload
    expect(run.status).to eq('done')
    expect(run.passed).to eq(1)
    failed = run.results.find { |r| r['case_id'] == first.id }
    expect(failed).to include('ok' => false)
    expect(failed['reason']).to include('No se pudo correr esta prueba')
  end

  it 'retoma donde iba: no repite las pruebas que ya tienen resultado' do
    run.update!(status: 'running')
    run.record!(ok(first))
    allow(runner).to receive(:run) { |c| ok(c) }

    perform_enqueued_jobs { described_class.perform_now(run.id) }
    expect(runner).to have_received(:run).once.with(second)
    expect(run.reload.passed).to eq(2)
  end

  it 'no hace nada con una corrida que ya terminó' do
    run.update!(status: 'failed')
    allow(runner).to receive(:run)
    described_class.perform_now(run.id)
    expect(runner).not_to have_received(:run)
  end

  it 'al terminar cierra los «Probar de nuevo» de esa corrida' do
    log = AgentTestLog.create!(account: account, tracking_template: template, kind: 'prompt', engine: '1', agent_test_case: first,
                               status: 'retesting', retest: { 'run_id' => run.id })
    allow(runner).to receive(:run) { |c| ok(c) }

    perform_enqueued_jobs { described_class.perform_now(run.id) }
    expect(log.reload.status).to eq('passed')
  end
end
