# frozen_string_literal: true

require 'rails_helper'

# proyecto@importar_prompt_md — F0 (docs/importar_prompt_md_plan.md §4.1)
RSpec.describe ContactTrackings::PromptImport::Reader do
  def fixture(name)
    Rails.root.join('spec/fixtures/files/prompt_import', name).read
  end

  describe 'un documento con reglas numeradas' do
    subject(:result) { described_class.call(fixture('reglas.md')) }

    it 'reconoce el formato y lee cada regla con sus campos, con o sin tildes' do
      expect(result).to be_ok
      expect(result.format).to eq(:rules)
      expect(result.rules.map(&:id)).to eq(%w[C0-01.01 C0-01.02 C7-01.01 C7-01.02])

      persona = result.rules.second
      expect(persona.to_h).to include(severity: 'inviolable', text: 'Nunca finjas ser una persona.',
                                      activation: 'Cuando pregunten si eres humano.',
                                      verification: 'Ninguna respuesta afirma ser persona.',
                                      prompt: 'No finjas ser humano.', role: :norm)
      expect(persona.path).to eq(['C0 · CONSTITUCIÓN', 'Identidad', 'Norma'])
    end

    it 'normaliza la gravedad y marca la desconocida como "otra"' do
      expect(result.rules.map(&:severity)).to eq(%w[obligatoria inviolable recomendada otra])
    end

    it 'acepta viñetas con asterisco y deja vacío el campo que falta' do
      precio = result.rules.third
      expect(precio.activation).to eq('Cuando pidan precio.')
      expect(precio.verification).to be_nil
    end

    it 'no toma como título ni como regla lo que está dentro de un bloque de código' do
      expect(result.blocks.map(&:title)).not_to include('esto no es un título')
      expect(result.rules.map(&:id)).not_to include('C9-99.99')
    end

    it 'da a cada bloque su ruta de títulos y hereda el rol hacia sus subtítulos' do
      intro = result.blocks.find { |b| b.title == 'Introducción' }
      expect(intro.path).to eq(['C0 · CONSTITUCIÓN', 'Identidad', 'Texto oficial', 'Introducción'])
      expect(intro.role).to eq(:official_text)
      expect(result.blocks.find { |b| b.title == 'Identidad' }.role).to be_nil
    end

    it 'resume el documento por capítulos, gravedad y rol' do
      stats = result.stats
      expect(stats[:rules_by_severity]).to eq('obligatoria' => 1, 'inviolable' => 1, 'recomendada' => 1, 'otra' => 1)
      expect(stats[:chapters].pluck(:title, :rules))
        .to eq([['Comportamiento Demo', 0], ['C0 · CONSTITUCIÓN', 2], ['C7 · PROTOCOLO COMERCIAL', 2]])
      expect(stats[:rules_without_prompt]).to eq(0)
      expect(stats[:chars_by_role].keys).to contain_exactly(:norm, :official_text)
    end
  end

  it 'un prompt común, sin reglas numeradas, queda en modo genérico con sus bloques' do
    result = described_class.call(fixture('generico.md'))

    expect(result.format).to eq(:generic)
    expect(result.rules).to be_empty
    expect(result.blocks.map(&:path)).to eq([['Agente de ventas'], ['Agente de ventas', 'Reglas'],
                                             ['Agente de ventas', 'Estilo']])
  end

  it 'lee igual un archivo de Windows con BOM' do
    windows = "﻿#{fixture('reglas.md').gsub("\n", "\r\n")}"

    expect(described_class.call(windows).rules.map(&:to_h)).to eq(described_class.call(fixture('reglas.md')).rules.map(&:to_h))
  end

  it 'rechaza un archivo vacío o más grande que el tope' do
    expect(described_class.call("  \n").error).to eq(:empty)
    expect(described_class.call('a' * (described_class::MAX_BYTES + 1)).error).to eq(:too_large)
  end

  # El documento real del usuario no va al repo (trae una parte marcada como confidencial):
  # esta prueba corre solo donde está.
  describe 'ADAM-2.0 (el ejemplo real)' do
    adam = '/tmp/adam/ADAM-2.0-Comportamiento.md'

    it 'lee sus 818 reglas en menos de un segundo', if: File.exist?(adam) do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = described_class.call(File.read(adam))
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(result.format).to eq(:rules)
      expect(result.stats[:rules_by_severity]).to eq('inviolable' => 373, 'obligatoria' => 419, 'recomendada' => 26)
      expect(result.stats[:chapters].size).to eq(9) # portada + C0…C7
      expect(result.stats[:rules_without_prompt]).to eq(0)
      expect(elapsed).to be < 1.0
    end
  end
end
