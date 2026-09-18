# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase E de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::LostRules do
  let(:antes) do
    <<~T
      @ruta(soporte #soporte1: no puedo entrar): -

      [MENSAJE CON DOS TEMAS]
      Si mezcla dos asuntos, responde solo el que puedas sustentar con la informacion recibida.
      Para el otro no supongas: pide el dato faltante o canalizalo.
      Aunque atiendas dos temas, cierra con UNA SOLA etiqueta, la del asunto principal.

      [ESTILO]
      Breve y amable con el cliente.
    T
  end

  def perdidas(despues)
    described_class.new(antes, despues).call
  end

  # El caso medido sobre el v6.11: la regla desapareció diciendo que era redundante.
  it 'encuentra la regla que ya no está en ningún lado' do
    despues = antes.sub("Aunque atiendas dos temas, cierra con UNA SOLA etiqueta, la del asunto principal.\n", '')

    expect(perdidas(despues)).to eq([{ section: '[MENSAJE CON DOS TEMAS]',
                                       rule: 'Aunque atiendas dos temas, cierra con UNA SOLA etiqueta, la del asunto principal.' }])
  end

  # Fusionar dos líneas en una no pierde nada: las palabras siguen estando.
  it 'no marca las reglas que se fusionaron con otra' do
    despues = antes.sub("Si mezcla dos asuntos, responde solo el que puedas sustentar con la informacion recibida.\n" \
                        "Para el otro no supongas: pide el dato faltante o canalizalo.\n",
                        'Si mezcla dos asuntos, responde solo el que puedas sustentar con la informacion recibida; ' \
                        "para el otro pide el dato faltante o canalizalo.\n")

    expect(perdidas(despues)).to be_empty
  end

  it 'no marca una regla que pasó a otra sección' do
    regla = 'Aunque atiendas dos temas, cierra con UNA SOLA etiqueta, la del asunto principal.'
    despues = "#{antes.sub("#{regla}\n", '')}\n[ETIQUETAS]\n#{regla}"

    expect(perdidas(despues)).to be_empty
  end

  it 'no mira las líneas de ruteo ni los renglones cortos' do
    despues = antes.sub("@ruta(soporte #soporte1: no puedo entrar): -\n", '').sub('Breve y amable con el cliente.', 'Breve.')

    expect(perdidas(despues).pluck(:rule)).to eq(['Breve y amable con el cliente.'])
  end
end
