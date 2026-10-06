# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase C de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::GuessedTags do
  let(:borrador) do
    <<~T
      @ruta(soporte #soporte1: no puedo entrar): <PENDIENTE: fuente>
      @ruta(precios #demo: cuanto cuesta): <PENDIENTE: fuente>
      @ruta(humano: pasame con alguien): -
    T
  end

  def quitar(dicho)
    described_class.strip(borrador, said: dicho)
  end

  # Medido: el modelo puso etiquetas antes de preguntarlas, en 3 de 3 entrevistas.
  it 'quita las etiquetas que la persona nunca escribió' do
    texto, quitadas = quitar(['quiero soporte y precios'])

    expect(texto).to include('@ruta(soporte: no puedo entrar)', '@ruta(precios: cuanto cuesta)')
    expect(quitadas).to eq(%w[#soporte1 #demo])
  end

  # Elegir con un botón manda "1) #demo"; sin "#" cuenta si el mensaje habla de etiquetas.
  it 'deja las que la persona eligió: con # o en un mensaje sobre etiquetas' do
    texto, quitadas = quitar(['1) #demo', 'etiqueta para soporte: soporte1'])

    expect(texto).to include('@ruta(soporte #soporte1:', '@ruta(precios #demo:')
    expect(quitadas).to be_empty
  end

  # Medido: "#soporte" y "#asesor" sobrevivían porque la persona escribió esas
  # palabras como temas. Nombrar el tema no es elegir la etiqueta.
  it 'no cuenta la palabra suelta en un mensaje que no habla de etiquetas' do
    _, quitadas = quitar(['1. soporte1: no puedo entrar', 'pasame con un demo'])

    expect(quitadas).to eq(%w[#soporte1 #demo])
  end

  # "demostracion" no es haber escrito "demo".
  it 'no cuenta la etiqueta dentro de otra palabra' do
    _, quitadas = quitar(['quiero agendar una demostracion'])

    expect(quitadas).to include('#demo')
  end

  it 'el resultado sigue siendo un borrador que el motor lee' do
    texto, = quitar([])

    expect(ContactTrackings::RouteMap.parse(texto).names).to eq(%w[soporte precios humano])
  end
end
