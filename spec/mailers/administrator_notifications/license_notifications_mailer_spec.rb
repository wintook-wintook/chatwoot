# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F3) — el correo de aviso, en el idioma de la cuenta
RSpec.describe AdministratorNotifications::LicenseNotificationsMailer do
  let(:account) { create(:account, name: 'Grúas del Sur', locale: 'es') }
  let!(:admin) { create(:user, account: account, role: :administrator, email: 'admin@gruas.test') }
  let(:licencia) { create(:account_license, account: account, name: 'Profesional', expires_at: 5.days.from_now) }
  let(:class_instance) { described_class.new }

  before do
    allow(described_class).to receive(:new).and_return(class_instance)
    allow(class_instance).to receive(:smtp_config_set_or_development?).and_return(true)
  end

  it 'llega a los administradores con los días y el plan' do
    mail = described_class.with(account: account).expiring(licencia, 5)

    expect(mail.to).to eq([admin.email])
    expect(mail.subject).to eq('Tu licencia vence en 5 días')
    expect(mail.body.encoded).to include('Profesional', 'Grúas del Sur')
  end
end
