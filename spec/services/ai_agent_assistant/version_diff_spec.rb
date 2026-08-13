# frozen_string_literal: true

# proyecto@ai_agent_assistant - F4
require 'rails_helper'

RSpec.describe AiAgentAssistant::VersionDiff do
  describe '.between' do
    it 'no reporta nada cuando los dos snapshots son iguales' do
      snapshot = { 'objective' => 'Cobrar', 'complementary_prompt' => "uno\ndos" }

      expect(described_class.between(snapshot, snapshot)).to be_empty
    end

    it 'reporta solo los campos que cambiaron' do
      diff = described_class.between(
        { 'objective' => 'Cobrar', 'timezone' => 'America/Mexico_City' },
        { 'objective' => 'Cobrar', 'timezone' => 'America/Monterrey' }
      )

      expect(diff.pluck(:field)).to eq(['timezone'])
      expect(diff.first[:from]).to eq('America/Mexico_City')
      expect(diff.first[:to]).to eq('America/Monterrey')
    end

    it 'marca qué líneas se quitaron y cuáles se pusieron' do
      diff = described_class.between(
        { 'complementary_prompt' => "Eres cobranza.\nNo prometas descuentos.\nCierra con gracias." },
        { 'complementary_prompt' => "Eres cobranza.\nOfrece plan de pagos.\nCierra con gracias." }
      )

      lines = diff.first[:lines]
      expect(lines.select { |op, _| op == 'del' }.map(&:last)).to eq(['No prometas descuentos.'])
      expect(lines.select { |op, _| op == 'add' }.map(&:last)).to eq(['Ofrece plan de pagos.'])
      expect(lines.select { |op, _| op == 'eq' }.map(&:last))
        .to eq(['Eres cobranza.', 'Cierra con gracias.'])
    end

    it 'reconstruye el texto original a partir de las operaciones' do
      antes    = "a\nb\nc"
      despues  = "a\nc\nd"
      ops      = described_class.line_ops(antes, despues)

      sin_altas = ops.filter_map { |op, line| line unless op == 'add' }
      sin_bajas = ops.filter_map { |op, line| line unless op == 'del' }

      expect(sin_altas.join("\n")).to eq(antes)
      expect(sin_bajas.join("\n")).to eq(despues)
    end

    it 'hace legibles las listas y los mapas' do
      diff = described_class.between(
        { 'keyword_actions' => [] },
        { 'keyword_actions' => [{ 'keyword' => 'pagado', 'action' => 'complete', 'direction' => 'incoming' }] }
      )

      expect(diff.first[:to]).to eq('keyword=pagado · action=complete · direction=incoming')
    end

    it 'trata nil y cadena vacía como el mismo valor (no es un cambio)' do
      expect(described_class.between({ 'ai_context' => nil }, { 'ai_context' => '' })).to be_empty
    end

    it 'contra un snapshot vacío devuelve todo lo que la versión contiene' do
      diff = described_class.between(nil, { 'objective' => 'Cobrar', 'ai_context' => '' })

      expect(diff.pluck(:field)).to eq(['objective'])
    end
  end
end
