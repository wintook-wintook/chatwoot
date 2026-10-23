# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F3) — cuando una licencia vence
RSpec.describe Licenses::ExpirationService do
  let(:account) { create(:account) }
  let(:enforced) { true }

  before { allow(Licenses::Enforcement).to receive(:enabled?).and_return(enforced) }

  def vencer!(now = Time.current)
    described_class.new(now: now).perform
  end

  it 'sin periodo en cola: vence y suspende la cuenta' do
    licencia = create(:account_license, account: account, starts_at: 31.days.ago, expires_at: 1.hour.ago)

    vencer!

    expect(licencia.reload).to be_expired
    expect(account.reload).to be_suspended
  end

  it 'con periodo en cola: lo promueve sin corte y conserva su inicio' do
    vigente = create(:account_license, account: account, starts_at: 31.days.ago, expires_at: 1.hour.ago)
    cola = create(:account_license, account: account, status: :scheduled, starts_at: vigente.expires_at, expires_at: 29.days.from_now)

    vencer!

    expect(cola.reload).to have_attributes(status: 'active', starts_at: vigente.expires_at)
    expect(account.reload).to be_active
  end

  it 'si el job corrió tarde y la de la cola también venció, se encadena a la siguiente' do
    create(:account_license, account: account, starts_at: 60.days.ago, expires_at: 30.days.ago)
    create(:account_license, account: account, status: :scheduled, starts_at: 30.days.ago, expires_at: 1.day.ago)
    tercera = create(:account_license, account: account, status: :scheduled, starts_at: 1.day.ago, expires_at: 29.days.from_now)

    vencer!

    expect(tercera.reload).to be_active
    expect(account.account_licenses.expired.count).to eq(2)
  end

  it 'promover reactiva una cuenta suspendida' do
    account.update!(status: :suspended)
    create(:account_license, account: account, status: :scheduled, starts_at: 1.hour.ago, expires_at: 29.days.from_now)

    vencer!

    expect(account.reload).to be_active
    expect(account.current_license).to be_present
  end

  it 'una cuenta de Wintook nunca se suspende' do
    account.update!(wintook_internal: true)
    create(:account_license, account: account, starts_at: 31.days.ago, expires_at: 1.hour.ago)

    vencer!

    expect(account.reload).to be_active
  end

  it 'al encender el interruptor suspende las que ya estaban vencidas de antes' do
    create(:account_license, account: account, status: :expired, starts_at: 60.days.ago, expires_at: 30.days.ago)

    vencer!

    expect(account.reload).to be_suspended
  end

  context 'when el interruptor está apagado' do
    let(:enforced) { false }

    it 'marca vencida pero no suspende' do
      licencia = create(:account_license, account: account, starts_at: 31.days.ago, expires_at: 1.hour.ago)

      vencer!

      expect(licencia.reload).to be_expired
      expect(account.reload).to be_active
    end
  end

  it 'no toca una licencia que todavía no vence ni una cuenta sin licencia' do
    otra = create(:account)
    licencia = create(:account_license, account: account, expires_at: 3.days.from_now)

    vencer!

    expect(licencia.reload).to be_active
    expect(otra.reload).to be_active
  end
end
