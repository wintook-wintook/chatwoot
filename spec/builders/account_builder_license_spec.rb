# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F1) — la demo al registrarse
RSpec.describe AccountBuilder do
  let!(:demo) { create(:license_plan, name: 'Demo', duration_days: 15, default_max_agents: 2, license_type: :demo, signup_default: true) }

  def registrar(**extra)
    described_class.new(account_name: 'Grúas del Sur', email: Faker::Internet.email, user_full_name: 'Ana',
                        user_password: 'Password1!', confirmed: true, **extra).perform
  end

  it 'una cuenta nueva nace con la demo del catálogo' do
    _user, account = registrar

    expect(account.current_license).to have_attributes(name: 'Demo', max_agents: 2, duration_days: 15, license_plan: demo)
  end

  it 'la cuenta de la instalación inicial (super admin) no recibe demo' do
    _user, account = registrar(super_admin: true)

    expect(account.account_licenses).to be_empty
  end

  it 'sin plan de registro el registro sigue y la cuenta queda fuera de licencia' do
    demo.update!(signup_default: false)

    _user, account = registrar

    expect(account).to be_persisted
    expect(account.account_licenses).to be_empty
  end
end
