# frozen_string_literal: true

require 'rails_helper'

# feat/licencias F6.2 — agregar agentes a la licencia vigente (D6a)
RSpec.describe Licenses::AgentIncrease do
  let(:account) { create(:account) }
  let(:licencia) { create(:account_license, account: account, max_agents: 5) }

  it 'sube el tope de la vigente y lo deja en el registro con el motivo' do
    described_class.new(license: licencia, add: '2', reason: '  pidió  dos más ').perform

    expect(licencia.reload.max_agents).to eq(7)
    registro = licencia.audits.last
    expect(registro.audited_changes['max_agents']).to eq([5, 7])
    expect(registro.comment).to eq('pidió dos más')
    expect(registro).to have_attributes(associated_type: 'Account', associated_id: account.id)
  end

  it 'solo sube: cero, negativos o texto se rechazan' do
    ['0', '-3', 'muchos', nil].each do |add|
      expect { described_class.new(license: licencia, add: add).perform }.to raise_error(described_class::Invalid)
    end
    expect(licencia.reload.max_agents).to eq(5)
  end

  it 'no toca una licencia que no es la vigente' do
    programada = create(:account_license, account: account, status: :scheduled, max_agents: 5,
                                          starts_at: 40.days.from_now, expires_at: 70.days.from_now)

    expect { described_class.new(license: programada, add: 2).perform }.to raise_error(described_class::Invalid)
  end
end
