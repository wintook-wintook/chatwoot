# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — F3/F4 de docs/importar_prompt_md_plan.md
RSpec.describe ContactTrackings::Assistant::BriefCoverage do
  let(:ficha) do
    { 'reglas' => [{ 'texto' => 'Una sola pregunta por mensaje' }, { 'texto' => 'Preguntar si es estudiante antes del precio' },
                   { 'texto' => 'Dar el precio sin hacer preguntas antes' }],
      'prohibiciones' => [{ 'texto' => 'Nunca pedir datos de tarjeta por WhatsApp' }],
      'datos_a_pedir' => [{ 'texto' => 'nombre' }, { 'texto' => 'teléfono' }],
      'contradicciones' => [{ 'sobre' => 'precio', 'a' => 'Preguntar si es estudiante antes del precio',
                              'b' => 'Dar el precio sin hacer preguntas antes' }] }
  end

  def cubrir(draft, answers = {})
    described_class.new(draft, ficha: ficha, answers: answers).call
  end

  # Medido con el gimnasio: la redacción de una sola vez soltó estas reglas.
  it 'agrega en su sección lo que la redacción dejó afuera' do
    draft = "[ROL]\nSoy Leo.\n\n[PROHIBIDO]\nNunca pido datos de tarjeta por WhatsApp.\n"

    resultado = cubrir(draft, { 'contradicciones' => { '0' => 'a' } })

    expect(resultado[:draft]).to include("[REGLAS]\n- Una sola pregunta por mensaje\n- Preguntar si es estudiante antes del precio")
    expect(resultado[:draft]).to include("[DATOS A PEDIR]\n- nombre\n- teléfono")
    expect(resultado[:added].pluck('section')).not_to include('PROHIBIDO') # ya estaba, con otras palabras
  end

  it 'no agrega la regla que la persona descartó en una contradicción' do
    resultado = cubrir("[ROL]\nx", { 'contradicciones' => { '0' => 'a' } })

    expect(resultado[:draft]).not_to include('Dar el precio sin hacer preguntas antes')
  end

  it 'agrega al final de una sección que ya existe' do
    draft = "[REGLAS]\n- Una sola pregunta por mensaje\n\n[ESTILO]\nDe tú."

    resultado = cubrir(draft)

    expect(resultado[:draft]).to start_with("[REGLAS]\n- Una sola pregunta por mensaje\n- Preguntar si es estudiante")
  end

  it 'quita los rótulos de instrucciones y la sección de pendientes' do
    draft = "═══ ZONA 1 · líneas de configuración ═══\n[ROL]\nx\n[PENDIENTE:]\n- nombre de la hoja\n[ESTILO]\ny"

    resultado = cubrir(draft)[:draft]

    expect(resultado).not_to include('ZONA 1')
    expect(resultado).not_to include('nombre de la hoja')
    expect(resultado).to include("[ESTILO]\ny")
  end

  it 'no toca un Entrenamiento que ya cubre todo' do
    draft = "[REGLAS]\n- Una sola pregunta por mensaje\n- Preguntar si es estudiante antes del precio\n" \
            "- Dar el precio sin hacer preguntas antes\n[PROHIBIDO]\n- Nunca pedir datos de tarjeta por WhatsApp\n" \
            "[DATOS A PEDIR]\n- nombre y teléfono"

    expect(cubrir(draft)).to eq(draft: draft, added: [])
  end
end
