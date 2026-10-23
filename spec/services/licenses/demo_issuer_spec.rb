# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F1)
RSpec.describe Licenses::DemoIssuer do
  let(:account) { create(:account) }
  let!(:demo) { create(:license_plan, name: 'Demo 7', duration_days: 7, default_max_agents: 1, license_type: :demo, signup_default: true) }

  it 'copia el plan de registro en una licencia activa' do
    freeze_time do
      licencia = described_class.new(account: account).perform

      expect(licencia).to have_attributes(status: 'active', name: 'Demo 7', license_type: 'demo', max_agents: 1,
                                          duration_days: 7, license_plan: demo, starts_at: Time.current,
                                          expires_at: 7.days.from_now)
      expect(licencia.metadata).to eq('source' => 'signup')
    end
  end

  it 'una cuenta que ya tiene licencias no recibe otra' do
    create(:account_license, account: account, status: :expired)

    expect(described_class.new(account: account).perform).to be_nil
    expect(account.account_licenses.count).to eq(1)
  end

  it 'sin plan de registro la cuenta queda fuera de licencia' do
    demo.update!(active: false)

    expect(described_class.new(account: account).perform).to be_nil
    expect(account.account_licenses).to be_empty
  end

  it 'un error no tumba nada: devuelve nil y lo deja en el log' do
    allow(account.account_licenses).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
    allow(Rails.logger).to receive(:error)

    expect(described_class.new(account: account).perform).to be_nil
    expect(Rails.logger).to have_received(:error).with(/demo no emitida/)
  end
end
