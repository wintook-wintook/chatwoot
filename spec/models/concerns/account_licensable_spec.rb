# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F0) — el tope de agentes que impone la licencia
RSpec.describe AccountLicensable do
  let(:account) { create(:account) }

  context 'when el interruptor está apagado' do
    before { allow(Licenses::Enforcement).to receive(:enabled?).and_return(false) }

    it 'no limita aunque haya licencia' do
      create(:account_license, account: account, max_agents: 3)

      expect(account.license_agent_limit).to be_nil
      expect(account.usage_limits[:agents]).to eq(ChatwootApp.max_limit.to_i)
    end
  end

  context 'when el interruptor está encendido' do
    before { allow(Licenses::Enforcement).to receive(:enabled?).and_return(true) }

    it 'sin licencia la cuenta queda fuera: como hoy' do
      expect(account.license_agent_limit).to be_nil
      expect(account.usage_limits[:agents]).to eq(ChatwootApp.max_limit.to_i)
    end

    it 'con licencia activa manda su tope, por encima del límite de la cuenta' do
      account.update!(limits: { agents: 40 })
      create(:account_license, account: account, max_agents: 3)

      expect(account.reload.usage_limits[:agents]).to eq(3)
    end

    it 'tuvo licencia y ninguna está activa: no admite agentes nuevos' do
      create(:account_license, account: account, status: :expired)

      expect(account.usage_limits[:agents]).to eq(0)
    end

    it 'una cuenta de Wintook nunca se limita' do
      account.update!(custom_attributes: { 'wintook_internal' => true })
      create(:account_license, account: account, max_agents: 3)

      expect(account.license_agent_limit).to be_nil
    end
  end

  it 'la marca «Cuenta de Wintook» no pisa otros atributos de la cuenta' do
    account.update!(custom_attributes: { 'plan_name' => 'x' })
    account.update!(wintook_internal: '1')

    expect(account.reload.custom_attributes).to include('plan_name' => 'x', 'wintook_internal' => true)
  end
end
