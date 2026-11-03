# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F0)
RSpec.describe LicensePlan do
  it 'pide nombre, días y agentes mayores a cero' do
    plan = described_class.new(name: '', duration_days: 0, default_max_agents: 0)

    expect(plan).not_to be_valid
    expect(plan.errors.attribute_names).to include(:name, :duration_days, :default_max_agents)
  end

  it 'features es una lista de nombres' do
    expect(build(:license_plan, features: %w[campaigns reports])).to be_valid
    expect(build(:license_plan, features: { campaigns: true })).not_to be_valid
  end

  it 'solo un plan es el de registro: marcar otro desmarca el anterior' do
    primero = create(:license_plan, signup_default: true, license_type: :demo)
    segundo = create(:license_plan, signup_default: true, license_type: :demo)

    expect(primero.reload.signup_default).to be(false)
    expect(described_class.signup_default_plan).to eq(segundo)
  end

  it 'un plan desactivado no es el de registro' do
    create(:license_plan, signup_default: true, active: false)

    expect(described_class.signup_default_plan).to be_nil
  end

  # Un plan nuevo arranca con lo que el sistema enciende a toda cuenta nueva.
  describe '.default_feature_names' do
    it 'usa lo que el super admin dejó encendido por defecto' do
      InstallationConfig.where(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').delete_all
      create(:installation_config, name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS',
                                   value: [{ 'name' => 'channel_whatsapp', 'enabled' => true },
                                           { 'name' => 'macros', 'enabled' => false },
                                           { 'name' => 'no_existe', 'enabled' => true }])

      expect(described_class.default_feature_names).to eq(['channel_whatsapp'])
    end

    it 'sin esa configuración, lo que trae config/features.yml' do
      InstallationConfig.where(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').delete_all

      esperadas = Featurable::FEATURE_LIST.select { |f| f['enabled'] }.pluck('name')
      expect(described_class.default_feature_names).to match_array(esperadas)
      expect(described_class.default_feature_names).to include('channel_email')
    end
  end
end
