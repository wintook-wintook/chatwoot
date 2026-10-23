# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F2)
RSpec.describe Licenses::Issuer do
  let(:account) { create(:account) }
  let(:plan) { create(:license_plan, name: 'Profesional', duration_days: 180, default_max_agents: 10) }
  let(:quien) { create(:user) }

  it 'activa ya, copiando el plan, y cancela la activa anterior' do
    anterior = create(:account_license, account: account, license_type: :demo)

    freeze_time do
      licencia = described_class.new(account: account, plan: plan, created_by: quien).perform

      expect(licencia).to have_attributes(status: 'active', name: 'Profesional', max_agents: 10, duration_days: 180,
                                          starts_at: Time.current, expires_at: 180.days.from_now, created_by: quien)
    end
    expect(anterior.reload).to be_cancelled
  end

  it 'deja ajustar agentes, días y nombre para esta cuenta' do
    licencia = described_class.new(account: account, plan: plan, max_agents: 12, duration_days: 45, name: 'Profesional+').perform

    expect(licencia).to have_attributes(max_agents: 12, duration_days: 45, name: 'Profesional+')
    expect(plan.reload.default_max_agents).to eq(10)
  end

  it 'en cola arranca al terminar la última vigente o programada' do
    vigente = create(:account_license, account: account, expires_at: 10.days.from_now)
    primera = described_class.new(account: account, plan: plan, start: 'queue').perform
    segunda = described_class.new(account: account, plan: plan, start: 'queue').perform

    expect(primera).to have_attributes(status: 'scheduled', starts_at: vigente.expires_at)
    expect(segunda.starts_at).to eq(primera.expires_at)
    expect(vigente.reload).to be_active
  end

  it 'en cola sin nada vigente arranca ya' do
    expect(described_class.new(account: account, plan: plan, start: 'queue').perform).to be_active
  end

  it 'reactiva una cuenta suspendida' do
    account.update!(status: :suspended)

    described_class.new(account: account, plan: plan).perform

    expect(account.reload).to be_active
  end

  it 'rechaza una forma de arrancar que no existe' do
    expect { described_class.new(account: account, plan: plan, start: 'manana').perform }.to raise_error(described_class::Invalid)
  end
end
