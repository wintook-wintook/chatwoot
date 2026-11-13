# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Ficha::Style do
  # Como el [ESTILO] de la plantilla 61 (cuenta 613): escrito a mano, de usted.
  let(:prompt) do
    "[ROL]\nSoy el asistente.\n\n[ESTILO]\nHablo de usted, en español de México, con un tono profesional, amable y serio. " \
      'Respuestas cortas y claras, de máximo 4 líneas, salvo la lista del catálogo. Sin emojis. Las ligas van como texto ' \
      "simple. Cierro con una pregunta sencilla para seguir la plática.\n\n[PROHIBIDO]\nNunca invento precios."
  end

  def estilo(texto) = described_class.read(texto)[:text]

  describe '.read' do
    it 'reconoce trato, tono y ajustes de un [ESTILO] escrito a mano' do
      expect(described_class.read(prompt).except(:text)).to eq(
        trato: 'usted', tone: 'profesional', tone_adjust: { 'emojis' => false, 'short' => false, 'question' => true }
      )
    end

    it 'sin [ESTILO] devuelve todo nil' do
      expect(described_class.read("[ROL]\nHola.")).to eq(trato: nil, tone: nil, tone_adjust: nil, text: nil)
    end

    it 'un tono escrito con otras palabras queda como nil, pero el trato sí se lee' do
      leido = described_class.read("[ESTILO]\nHablo de tú, con humor y mucha paciencia.")
      expect(leido.values_at(:trato, :tone)).to eq(['tu', nil])
    end
  end

  describe '.update' do
    it 'si nada cambió, el prompt queda idéntico' do
      expect(described_class.update(prompt, trato: 'usted', tone: 'profesional',
                                            tone_adjust: { 'emojis' => false, 'short' => false, 'question' => true })).to eq(prompt)
    end

    it 'solo el trato: cambia «usted» por «tú» y nada más' do
      nuevo = described_class.update(prompt, trato: 'tu')
      expect(estilo(nuevo)).to start_with('Hablo de tú, en español de México, con un tono profesional')
      expect(nuevo.sub('Hablo de tú', 'Hablo de usted')).to eq(prompt)
    end

    it 'tono y ajustes nuevos conservan lo que la persona escribió' do
      nuevo = estilo(described_class.update(prompt, tone: 'cercano', tone_adjust: { 'short' => true, 'question' => false }))

      expect(nuevo).to start_with('Hablo de usted, en español de México, cálido y cercano')
      expect(nuevo).to include('Respuestas muy cortas: máximo 2 líneas, salvo la lista del catálogo.', 'Las ligas van como texto simple.')
      expect(nuevo).not_to include('Cierro con una pregunta')
    end

    it 'prende emojis cambiando «Sin emojis.»' do
      nuevo = estilo(described_class.update(prompt, tone_adjust: { 'emojis' => true }))
      expect(nuevo).to include(described_class::EMOJIS)
      expect(nuevo).not_to include(described_class::NO_EMOJIS)
    end

    it 'no toca nada fuera de [ESTILO]' do
      nuevo = described_class.update(prompt, trato: 'tu', tone: 'directo', tone_adjust: { 'emojis' => true })
      expect(nuevo).to start_with("[ROL]\nSoy el asistente.\n\n[ESTILO]\n").and end_with("\n\n[PROHIBIDO]\nNunca invento precios.")
    end

    it 'sin [ESTILO] lo crea completo al final' do
      expect(described_class.update("[ROL]\nHola.", trato: 'usted', tone: 'directo')).to eq(
        "[ROL]\nHola.\n\n[ESTILO]\nHablo de usted, en español de México, directo y sin rodeos: digo lo necesario. " \
        'Respuestas muy cortas: máximo 2 líneas. Sin emojis.'
      )
    end
  end
end
