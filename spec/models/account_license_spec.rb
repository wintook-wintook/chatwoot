# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F0)
RSpec.describe AccountLicense do
  let(:account) { create(:account) }

  it 'una cuenta tiene a lo sumo una licencia activa' do
    create(:account_license, account: account)
    otra = build(:account_license, account: account)

    expect(otra).not_to be_valid
    expect { otra.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'admite varias programadas junto a la activa' do
    create(:account_license, account: account)
    create(:account_license, account: account, status: :scheduled)

    expect(build(:account_license, account: account, status: :scheduled)).to be_valid
  end

  it 'vence después de empezar' do
    licencia = build(:account_license, starts_at: Time.current, expires_at: 1.day.ago)

    expect(licencia).not_to be_valid
    expect(licencia.errors.attribute_names).to include(:expires_at)
  end

  it 'editar el plan no cambia la licencia emitida (copia)' do
    plan = create(:license_plan, default_max_agents: 5)
    licencia = create(:account_license, account: account, license_plan: plan, max_agents: plan.default_max_agents)

    plan.update!(default_max_agents: 50)

    expect(licencia.reload.max_agents).to eq(5)
  end
end
