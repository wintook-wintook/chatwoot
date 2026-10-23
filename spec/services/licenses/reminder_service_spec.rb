# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F3) — avisos 10 y 5 días antes
RSpec.describe Licenses::ReminderService do
  let(:account) { create(:account) }
  let(:mail) { instance_double(ActionMailer::MessageDelivery, deliver_later: true) }
  let(:mailer) { double(expiring: mail) } # rubocop:disable RSpec/VerifiedDoubles

  before do
    allow(Licenses::Enforcement).to receive(:enabled?).and_return(true)
    allow(AdministratorNotifications::LicenseNotificationsMailer).to receive(:with).and_return(mailer)
  end

  it 'avisa a los 10 días y otra vez a los 5, cada uno una sola vez' do
    licencia = create(:account_license, account: account, expires_at: 9.days.from_now)

    # Solo los de ESTA licencia: la base de pruebas es la de dev y puede tener otras.
    2.times { described_class.new.perform }
    expect(mailer).to have_received(:expiring).with(licencia, anything).once
    expect(licencia.reload.reminded_at.keys).to eq(['10'])

    described_class.new(now: 5.days.from_now).perform
    expect(mailer).to have_received(:expiring).with(licencia, anything).twice
    expect(licencia.reload.reminded_at.keys).to contain_exactly('10', '5')
  end

  it 'no avisa con más de 10 días, a una cuenta de Wintook ni si ya tiene periodo en cola' do
    create(:account_license, account: account, expires_at: 20.days.from_now)
    interna = create(:account, custom_attributes: { 'wintook_internal' => true })
    create(:account_license, account: interna, expires_at: 3.days.from_now)
    con_cola = create(:account)
    create(:account_license, account: con_cola, expires_at: 3.days.from_now)
    create(:account_license, account: con_cola, status: :scheduled)

    described_class.new.perform

    expect(mailer).not_to have_received(:expiring).with(have_attributes(account_id: account.id), anything)
    expect(mailer).not_to have_received(:expiring).with(have_attributes(account_id: interna.id), anything)
    expect(mailer).not_to have_received(:expiring).with(have_attributes(account_id: con_cola.id), anything)
  end

  it 'con el interruptor apagado no avisa' do
    allow(Licenses::Enforcement).to receive(:enabled?).and_return(false)
    create(:account_license, account: account, expires_at: 3.days.from_now)

    described_class.new.perform

    expect(AdministratorNotifications::LicenseNotificationsMailer).not_to have_received(:with)
  end
end
