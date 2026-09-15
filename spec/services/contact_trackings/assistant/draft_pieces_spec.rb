# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase B de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::DraftPieces do
  let(:texto) do
    <<~T
      @ruta(soporte #soporte1: no puedo entrar): @buscar_articulo
      @ruta(precios #comercial1: cuanto cuesta): @buscar_predefinidas
      @ruta_por_defecto: soporte

      [QUIEN ERES]
      Sos el asistente de Kontrolya.

      [ESTILO]
      Breve y amable.

      [NO SIMULAR]
      Nunca digas que ya quedó agendado.
    T
  end

  # Todo lo demás se apoya en esto: si cortar y rearmar cambia un carácter, restaurar
  # una pieza le cambiaría a la persona texto que nadie tocó.
  it 'rearma el texto exactamente igual, incluidos los renglones en blanco' do
    ['', texto, "suelto\n\n#{texto}", "#{texto}\n\n\n", "[A]\nuno\n@ruta(x #xx_x: y): -\ndos"].each do |t|
      expect(described_class.new(t).to_s).to eq(t)
    end
  end

  it 'reconoce ramas, rama por defecto y secciones con cualquier rótulo' do
    expect(described_class.new(texto).pieces.values.map(&:label))
      .to eq(['@ruta(soporte)', '@ruta(precios)', '@ruta_por_defecto', '[QUIEN ERES]', '[ESTILO]', '[NO SIMULAR]'])
  end

  # Los renglones vacíos entre las rutas y el primer rótulo no son contenido.
  it 'no cuenta como pieza la prosa suelta en blanco' do
    expect(described_class.new(texto).pieces).not_to have_key(described_class::PREAMBLE_KEY)
    expect(described_class.new("Intro.\n#{texto}").pieces).to have_key(described_class::PREAMBLE_KEY)
  end

  describe '.restore' do
    let(:del_asistente) { texto.sub('Breve y amable.', 'Breve.').sub('cuanto cuesta', 'cuanto sale') }

    def restaurar(theirs, mine, keys)
      described_class.restore(theirs: theirs, mine: mine, keys: keys)
    end

    # El caso de la fase B: la persona editó [ESTILO] a mano, el asistente lo pisó
    # mientras cambiaba otra cosa. Vuelve lo de la persona; lo otro se queda.
    it 'devuelve la pieza de la persona y conserva los demás cambios del asistente' do
      mio = texto.sub('Breve y amable.', "Breve y amable.\nSin emojis.")

      resultado = restaurar(del_asistente, mio, ['[ESTILO]'])

      expect(resultado).to include("[ESTILO]\nBreve y amable.\nSin emojis.")
      expect(resultado).to include('cuanto sale')
      expect(resultado.lines.size).to eq(del_asistente.lines.size + 1)
    end

    it 'vuelve a poner en su lugar una sección que el asistente quitó' do
      sin_seccion = texto.sub("[ESTILO]\nBreve y amable.\n\n", '')

      expect(restaurar(sin_seccion, texto, ['[ESTILO]'])).to eq(texto)
    end

    it 'vuelve a poner una rama que el asistente quitó, detrás de la que la precedía' do
      sin_rama = texto.sub("@ruta(precios #comercial1: cuanto cuesta): @buscar_predefinidas\n", '')

      expect(restaurar(sin_rama, texto, ['@ruta(precios)'])).to eq(texto)
    end

    # Si la persona la había borrado a mano y el asistente la volvió a escribir.
    it 'quita una pieza que la persona había borrado' do
      mio = texto.sub("[NO SIMULAR]\nNunca digas que ya quedó agendado.\n", '')

      expect(restaurar(texto, mio, ['[NO SIMULAR]'])).not_to include('[NO SIMULAR]')
    end

    it 'acepta la clave escrita con otras mayúsculas o tildes' do
      mio = texto.sub('Sos el asistente', 'Sos la asistente')

      expect(restaurar(texto, mio, ['[quién eres]'])).to include('Sos la asistente')
    end
  end
end
