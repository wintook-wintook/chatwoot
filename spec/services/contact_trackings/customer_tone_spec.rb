# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::CustomerTone do
  describe '.trato' do
    it 'lee usted en la sección [ESTILO] (cuenta 613, plantilla 61)' do
      prompt = "[ROL]\nSoy el asistente.\n\n[ESTILO]\nHablo de usted, en español de México, con un tono profesional.\n\n[PROHIBIDO]\nNada."
      expect(described_class.trato(prompt)).to eq(:usted)
    end

    it 'lee tú en la sección [ESTILO] que escribe el Asistente' do
      prompt = "[ESTILO]\nHablo de tú, en español de México, cálido y cercano.\n"
      expect(described_class.trato(prompt)).to eq(:tu)
    end

    it 'la sección de estilo manda sobre lo que diga el resto del prompt' do
      prompt = "[REGLAS]\nSi el cliente le habla de tú, siga igual.\n\n[ESTILO]\nTrate al cliente de usted.\n"
      expect(described_class.trato(prompt)).to eq(:usted)
    end

    it 'sin sección de estilo busca en todo el prompt' do
      expect(described_class.trato('Eres ADAM. Siempre trata al cliente de usted.')).to eq(:usted)
    end

    it 'no lee al revés «no hable de usted»' do
      expect(described_class.trato("[ESTILO]\nNo hable de usted, hable de tú.")).to eq(:tu)
    end

    it 'lee «SIEMPRE DE USTED» y «un tono de usted»' do
      expect(described_class.trato("[TONO]\nSIEMPRE DE USTED (\"usted\", \"le\", \"su\") y en plural.")).to eq(:usted)
      expect(described_class.trato('Lumi se comunica de manera cordial, utilizando un tono de usted.')).to eq(:usted)
    end

    it 'si el trato cambia según el cliente, manda el prompt (ADAM)' do
      prompt = 'Trato: háblale de usted al prospecto. Solo si él te habla de tú, cambia a tú y sostenlo.'
      expect(described_class.trato(prompt)).to eq(:instrucciones)
      expect(described_class.trato('Trata de tú, salvo que el cliente escriba de usted.')).to eq(:instrucciones)
    end

    it 'devuelve :instrucciones si dice las dos cosas y nil si no dice nada' do
      expect(described_class.trato('Hablo de tú. Hablo de usted.')).to eq(:instrucciones)
      expect(described_class.trato("[ESTILO]\nSin emojis.")).to be_nil
      expect(described_class.trato(nil)).to be_nil
    end
  end

  describe '.rule_for' do
    it 'con usted pide usted aunque el cliente o las fuentes estén de tú' do
      rule = described_class.rule_for("[ESTILO]\nHablo de usted.")
      expect(rule).to include('de USTED').and include('Nunca lo tutees')
      expect(rule).not_to include('háblale de tú')
    end

    it 'con tú pide tú' do
      expect(described_class.rule_for("[ESTILO]\nHablo de tú.")).to eq(described_class::RULE_TU)
    end

    it 'con trato condicional no impone ninguno' do
      rule = described_class.rule_for('Háblale de usted. Solo si él te habla de tú, cambia a tú.')
      expect(rule).to eq(described_class::RULE_INSTRUCCIONES)
    end

    it 'sin agente o sin trato en el prompt queda la regla de siempre' do
      expect(described_class.rule_for(nil)).to eq(described_class::RULE)
      expect(described_class.rule_for("[ESTILO]\nSin emojis.")).to eq(described_class::RULE)
    end
  end
end
