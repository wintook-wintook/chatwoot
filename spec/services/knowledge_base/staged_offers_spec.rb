# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeBase::StagedOffers do
  let(:definition) do
    ContactTrackings::ConversationVariables.parse(<<~PROMPT)
      [VARIABLES]
      CARRERA = VACÍO | valor
      SIGUIENTE_OFERTA = PRIMERA_BECA | SEGUNDA_BECA | AGOTADA
      Inicial: CARRERA=VACÍO; SIGUIENTE_OFERTA=PRIMERA_BECA
    PROMPT
  end
  # Como la ficha de Trabajo Social en dev (cuenta 1128).
  let(:ficha) do
    <<~FICHA
      COSTOS Y BECAS
      - Precio normal por materia: $3,221.00
      - Primera beca: 38% toda la Licenciatura, paga $ 1,990.00 por materia, cupón: l0601202611.
      {{tsbeca1mat}}
      - Segunda beca: 52% los 3 primeros cuatrimestres, paga $ 1,540.00 por materia, cupón: l0602202611.
      {{tsbeca2mat}}
      - Última beca: NO HAY

      INSCRIPCIÓN Y REINSCRIPCIÓN
      - Liga para inscribirse: https://neoclase.com/cursos/ts101/
    FICHA
  end

  def filtrar(texto, oferta)
    described_class.filter(texto, definition, { 'CARRERA' => 'Trabajo Social', 'SIGUIENTE_OFERTA' => oferta })
  end

  it 'con PRIMERA_BECA quita la segunda beca y su imagen, y deja todo lo demás' do
    salida = filtrar(ficha, 'PRIMERA_BECA')

    expect(salida).not_to include('Segunda beca')
    expect(salida).not_to include('l0602202611')
    expect(salida).not_to include('{{tsbeca2mat}}')
    expect(salida).to include('Primera beca', '{{tsbeca1mat}}', 'Precio normal', 'Última beca: NO HAY', 'Liga para inscribirse')
  end

  it 'deja un aviso en lugar de la oferta oculta, para que no diga «no hay otra beca»' do
    salida = filtrar(ficha, 'PRIMERA_BECA')

    aviso = salida.lines.find { |l| l.include?('todavía no toca') }
    expect(salida.lines.count { |l| l.include?('todavía no toca') }).to eq(1)
    expect(salida.index(aviso)).to be > salida.index('{{tsbeca1mat}}')
  end

  it 'con SEGUNDA_BECA deja las dos (la primera ya se entregó y la pueden reclamar)' do
    expect(filtrar(ficha, 'SEGUNDA_BECA')).to eq(ficha)
  end

  it 'con AGOTADA deja todo' do
    expect(filtrar(ficha, 'AGOTADA')).to eq(ficha)
  end

  it 'entiende la ficha de prod: viñetas *, imagen con sangría y líneas en blanco' do
    prod = "* Precio normal por materia: $4,429.00\n\n* Primera beca: 42%, paga $ 2,600.00\n  {{manbeca1mat}}\n\n" \
           "* Segunda beca: 50% el primer cuatrimestre\n  {{manbeca2mat}}\n\n* Última beca: NO HAY\n"
    salida = filtrar(prod, 'PRIMERA_BECA')

    expect(salida).not_to include('Segunda beca', '{{manbeca2mat}}')
    expect(salida).to include('Primera beca', '{{manbeca1mat}}', 'Última beca')
  end

  it 'no toca un texto que no es lista de ofertas' do
    texto = "Formas de titulación:\n- Tesis: investigación.\n- Segunda beca: mencionada una sola vez.\n"
    expect(filtrar(texto, 'PRIMERA_BECA')).to eq(texto)
  end

  it 'no aplica a variables que no son de «siguiente» oferta' do
    otra = ContactTrackings::ConversationVariables.parse("[VARIABLES]\nOFERTA_DADA = PRIMERA_BECA | SEGUNDA_BECA\n")
    expect(described_class.filter(ficha, otra, { 'OFERTA_DADA' => 'PRIMERA_BECA' })).to eq(ficha)
  end

  it 'sin [VARIABLES] devuelve el contenido igual' do
    expect(described_class.filter(ficha, ContactTrackings::ConversationVariables.parse('Sin variables.'), {})).to eq(ficha)
  end

  it 'el aviso nombra la oferta que toca ahora, como se llama en la ficha (prod 613 conv 88)' do
    salida = filtrar(ficha, 'PRIMERA_BECA')
    expect(salida).to include('lo que le toca ahora es «Primera beca», la de arriba')
    expect(salida).not_to include('Segunda beca')
  end

  it 'si la oferta actual no tiene renglón en la ficha, queda el aviso general' do
    sin_inscripcion = ContactTrackings::ConversationVariables.parse(
      "[VARIABLES]\nSIGUIENTE_OFERTA = SIN_INSCRIPCION | PRIMERA_BECA | SEGUNDA_BECA\n"
    )
    salida = described_class.filter(ficha, sin_inscripcion, { 'SIGUIENTE_OFERTA' => 'SIN_INSCRIPCION' })
    expect(salida).to include(described_class::PLACEHOLDER)
    expect(salida).not_to include('Primera beca', 'Segunda beca')
  end

  describe '.one_step' do
    let(:actuales) { { 'SIGUIENTE_OFERTA' => 'PRIMERA_BECA', 'CARRERA' => 'Trabajo Social' } }

    it 'si el modelo se salta un paso, guarda solo el siguiente' do
      expect(described_class.one_step(definition, actuales, { 'SIGUIENTE_OFERTA' => 'AGOTADA' }))
        .to eq({ 'SIGUIENTE_OFERTA' => 'SEGUNDA_BECA' })
    end

    it 'un paso o retroceder se guarda tal cual, y no toca otras variables' do
      expect(described_class.one_step(definition, actuales, { 'SIGUIENTE_OFERTA' => 'SEGUNDA_BECA', 'CARRERA' => 'Derecho' }))
        .to eq({ 'SIGUIENTE_OFERTA' => 'SEGUNDA_BECA', 'CARRERA' => 'Derecho' })
      expect(described_class.one_step(definition, { 'SIGUIENTE_OFERTA' => 'AGOTADA' }, { 'SIGUIENTE_OFERTA' => 'PRIMERA_BECA' }))
        .to eq({ 'SIGUIENTE_OFERTA' => 'PRIMERA_BECA' })
    end
  end
end
