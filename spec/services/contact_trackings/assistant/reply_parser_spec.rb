# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::ReplyParser do
  # Las opciones las escribe el MODELO, así que se leen con desconfianza: sin tope,
  # una respuesta rara deja la conversación cubierta de botones.
  describe '.options' do
    it 'devuelve las preguntas con sus elecciones' do
      salida = described_class.options(
        'opciones' => [{ 'pregunta' => '¿Con qué etiqueta cierra?',
                         'elecciones' => ['#demo', '#tracking', 'otra'] }]
      )

      expect(salida).to eq([{ question: '¿Con qué etiqueta cierra?',
                              choices: ['#demo', '#tracking', 'otra'] }])
    end

    # El tope se calcula desde la constante y no con un número escrito a mano: al
    # subirlo de 6 a 10 este ejemplo se quedó pasando 9 —por debajo del tope— y
    # dejó de probar nada. Atado a la constante, sigue probando el recorte aunque
    # el tope cambie.
    it 'recorta la cantidad de preguntas y de botones' do
      de_mas = described_class::MAX_QUESTIONS + 3
      salida = described_class.options(
        'opciones' => Array.new(de_mas) { |i| { 'pregunta' => "p#{i}", 'elecciones' => Array.new(12) { |j| "o#{j}" } } }
      )

      expect(salida.size).to eq(described_class::MAX_QUESTIONS)
      expect(salida.first[:choices].size).to eq(described_class::MAX_CHOICES)
    end

    # Un botón sin texto no sirve para nada, y una pregunta sin botones tampoco.
    it 'descarta las preguntas que quedaron sin elecciones' do
      salida = described_class.options(
        'opciones' => [{ 'pregunta' => 'sin nada', 'elecciones' => ['', '  '] },
                       { 'pregunta' => 'buena', 'elecciones' => ['sí'] }]
      )

      expect(salida.pluck(:question)).to eq(['buena'])
    end

    it 'no revienta con lo que no es una lista' do
      expect(described_class.options({})).to be_nil
      expect(described_class.options('opciones' => 'a, b')).to be_nil
      expect(described_class.options('opciones' => [])).to be_nil
      expect(described_class.options('opciones' => ['suelta'])).to be_nil
    end
  end
end
