# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase B de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::ManualEdits do
  let(:entregado) do
    <<~T
      @ruta(soporte #soporte1: no puedo entrar): @buscar_articulo

      [ESTILO]
      Breve.

      [NO SIMULAR]
      Nunca digas que ya quedó agendado.
    T
  end
  # La persona editó [ESTILO] a mano.
  let(:en_pantalla) { entregado.sub('Breve.', "Breve.\nSin emojis.") }

  def manual(delivered: entregado, current: en_pantalla)
    described_class.new(delivered: delivered, current: current)
  end

  describe 'qué editó la persona' do
    it 'nombra las piezas que cambiaron desde la última entrega' do
      expect(manual.labels).to eq(['[ESTILO]'])
    end

    # Sin saber qué entregó el asistente no hay con qué comparar.
    it 'no detecta nada si no se sabe qué entregó el asistente' do
      expect(manual(delivered: nil).any?).to be(false)
    end

    # Todavía no hubo entrega: todo lo que hay lo escribió la persona.
    it 'considera todo editado a mano si todavía no hubo entrega' do
      expect(manual(delivered: '').labels).to eq(['@ruta(soporte)', '[ESTILO]', '[NO SIMULAR]'])
    end
  end

  describe '#resolve' do
    it 'no hace nada si el asistente respetó lo editado a mano' do
      del_asistente = en_pantalla.sub('Nunca digas', 'Jamás digas')

      expect(manual.resolve(del_asistente, ['[NO SIMULAR]'])).to be_nil
    end

    # El caso de la fase B: pisó [ESTILO] sin declararlo mientras cambiaba otra cosa.
    it 'devuelve la versión de la persona y conserva lo demás que cambió el asistente' do
      del_asistente = entregado.sub('Nunca digas', 'Jamás digas')

      resuelto = manual.resolve(del_asistente, ['[NO SIMULAR]'])

      expect(resuelto[:draft]).to include("Breve.\nSin emojis.")
      expect(resuelto[:draft]).to include('Jamás digas')
      expect(resuelto[:conflict][:assistant_draft]).to eq(del_asistente)
      expect(resuelto[:conflict][:items]).to eq([{ key: '[ESTILO]', mine: "[ESTILO]\nBreve.\nSin emojis.\n",
                                                   theirs: "[ESTILO]\nBreve.\n" }])
    end

    # Si lo nombró en `toca`, la persona se lo pidió en este mensaje.
    it 'no devuelve nada que el asistente haya declarado haber cambiado' do
      expect(manual.resolve(entregado.sub('Breve.', 'Corto.'), ['[estilo]'])).to be_nil
    end

    it 'devuelve una sección editada a mano que el asistente borró' do
      del_asistente = entregado.sub("[ESTILO]\nBreve.\n\n", '')

      resuelto = manual.resolve(del_asistente, [])

      expect(resuelto[:draft]).to include("[ESTILO]\nBreve.\nSin emojis.")
      expect(resuelto[:conflict][:items].first).to include(key: '[ESTILO]', theirs: nil)
    end
  end
end
