# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F0) — el interruptor vive en InstallationConfig, no en .env
RSpec.describe Licenses::Enforcement do
  after { GlobalConfig.clear_cache }

  it 'apagado por omisión' do
    InstallationConfig.where(name: described_class::CONFIG_KEY).delete_all
    GlobalConfig.clear_cache

    expect(described_class.enabled?).to be(false)
  end

  it 'se enciende desde la configuración del super admin' do
    InstallationConfig.where(name: described_class::CONFIG_KEY).first_or_create(value: false, locked: false).update!(value: true)

    expect(described_class.enabled?).to be(true)
  end
end
