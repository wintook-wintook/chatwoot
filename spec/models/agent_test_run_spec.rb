# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentTestRun do
  let(:account) { create(:account) }
  let(:template) { create(:tracking_template, account: account) }
  let(:batch) { AgentTestBatch.create!(account: account, tracking_template: template, name: 'Lote') }

  before { batch.cases.create!(account: account, name: 'Uno', messages: ['Hola'], expected: 'Saluda') }

  describe '.start!' do
    it 'encola una corrida nueva con el total de pruebas del lote' do
      run = nil
      expect { run = described_class.start!(batch: batch, template: template, user: nil) }
        .to have_enqueued_job(AgentTester::RunJob)
      expect(run).to have_attributes(status: 'queued', total: 1)
    end

    it 'con doble «Correr» devuelve la que ya va, no encola otra' do
      first = described_class.start!(batch: batch, template: template, user: nil)
      first.update!(status: 'running')
      expect { described_class.start!(batch: batch, template: template, user: nil) }.not_to change(described_class, :count)
      expect(described_class.start!(batch: batch, template: template, user: nil)).to eq(first)
    end

    it 'sí encola otra si la anterior ya terminó o si son otras pruebas' do
      first = described_class.start!(batch: batch, template: template, user: nil)
      other = described_class.start!(batch: batch, template: template, user: nil, case_ids: [batch.cases.first.id])
      expect(other).not_to eq(first)
      first.update!(status: 'done')
      expect(described_class.start!(batch: batch, template: template, user: nil)).not_to eq(first)
    end
  end

  describe '.close_stale!' do
    it 'marca fallidas con su motivo las corridas que dejaron de avanzar, y sus «Probar de nuevo»' do
      stale = described_class.start!(batch: batch, template: template, user: nil)
      stale.update_columns(status: 'running', updated_at: 31.minutes.ago) # rubocop:disable Rails/SkipsModelValidations
      fresh = described_class.start!(batch: batch, template: template, user: nil, case_ids: [batch.cases.first.id])
      log = AgentTestLog.create!(account: account, tracking_template: template, kind: 'prompt', engine: '1',
                                 agent_test_case: batch.cases.first, status: 'retesting', retest: { 'run_id' => stale.id })

      described_class.close_stale!
      expect(stale.reload).to have_attributes(status: 'failed', error: described_class::STALE_REASON)
      expect(fresh.reload.status).to eq('queued')
      expect(log.reload.status).to eq('failing')
    end
  end
end
