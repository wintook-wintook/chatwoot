# frozen_string_literal: true

# proyecto@ai_agent_assistant - F4
require 'rails_helper'

RSpec.describe AiAgentAssistant::SiblingDetector do
  let(:account) { create(:account) }

  describe '.base_name' do
    it 'reconoce los marcadores explícitos de versión' do
      expect(described_class.base_name('TICKETS UNIDADES V4')).to eq('TICKETS UNIDADES')
      expect(described_class.base_name('Cobranza - v2')).to eq('Cobranza')
      expect(described_class.base_name('Cobranza versión 3')).to eq('Cobranza')
      expect(described_class.base_name('Cobranza ver. 10')).to eq('Cobranza')
    end

    # Un «Recordatorio 2» puede ser el segundo paso de una secuencia, no una copia:
    # proponer archivarlo sería un consejo caro.
    it 'no inventa versiones donde solo hay un número' do
      expect(described_class.base_name('Recordatorio 2')).to be_nil
      expect(described_class.base_name('Cobranza 30 días')).to be_nil
      expect(described_class.base_name('Cobranza')).to be_nil
    end
  end

  describe '.for' do
    it 'agrupa las copias del mismo caso de uso' do
      v1 = create(:tracking_template, account: account, name: 'TICKETS UNIDADES V1')
      v2 = create(:tracking_template, account: account, name: 'TICKETS UNIDADES V2')
      create(:tracking_template, account: account, name: 'COBRANZA V1')

      siblings = described_class.for(v2)

      expect(siblings.pluck(:id)).to eq([v1.id, v2.id])
      expect(siblings.pluck(:version)).to eq([1, 2])
      expect(siblings.find { |s| s[:id] == v2.id }[:current]).to be(true)
    end

    it 'no agrupa nombres que solo comparten prefijo' do
      v4 = create(:tracking_template, account: account, name: 'Tickets V4')
      create(:tracking_template, account: account, name: 'Tickets Verano V1')

      expect(described_class.for(v4)).to be_empty
    end

    it 'devuelve vacío cuando la copia está sola' do
      solo = create(:tracking_template, account: account, name: 'Cobranza V2')

      expect(described_class.for(solo)).to be_empty
    end

    it 'no cruza cuentas' do
      mia = create(:tracking_template, account: account, name: 'Cobranza V1')
      create(:tracking_template, account: create(:account), name: 'Cobranza V2')

      expect(described_class.for(mia)).to be_empty
    end

    it 'informa si la copia está archivada y cuántos seguimientos tiene' do
      v1 = create(:tracking_template, account: account, name: 'Cobranza V1')
      v2 = create(:tracking_template, account: account, name: 'Cobranza V2')
      v1.archive!

      entrada = described_class.for(v2).find { |s| s[:id] == v1.id }
      expect(entrada[:archived]).to be(true)
      expect(entrada[:trackings_count]).to eq(0)
    end
  end
end
