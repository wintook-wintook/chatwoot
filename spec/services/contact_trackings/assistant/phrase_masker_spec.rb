# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::PhraseMasker do
  def enmascarar(texto)
    described_class.call(texto)
  end

  describe 'lo que tapa' do
    it 'tapa un correo' do
      expect(enmascarar('escribime a juan.perez@empresa.com.mx y te paso los datos'))
        .to eq('escribime a [correo] y te paso los datos')
    end

    it 'tapa un teléfono de 10 dígitos, con o sin separadores' do
      expect(enmascarar('mi celular es 55 1234 5678')).to include('[telefono]')
      expect(enmascarar('llamame al (55) 1234-5678')).to include('[telefono]')
      expect(enmascarar('mi numero 5512345678 por favor')).to include('[telefono]')
    end

    it 'tapa un RFC' do
      expect(enmascarar('mi rfc es GODE561231GR8 para la factura')).to include('[rfc]')
    end

    it 'tapa una CURP antes de que el patrón de RFC la deje a medias' do
      resultado = enmascarar('mi curp GOME560231HDFNRL05 no la reconoce')

      expect(resultado).to include('[curp]')
      expect(resultado).not_to include('[rfc]')
    end

    it 'tapa un folio largo suelto' do
      expect(enmascarar('no encuentro la factura 902384756 en el sistema'))
        .to eq('no encuentro la factura [numero] en el sistema')
    end
  end

  # Esto es lo que hace que enmascarar NO cueste calidad: lo que sobrevive es
  # justo el vocabulario con el que se escriben las descripciones de cada rama.
  describe 'lo que deja intacto, a propósito' do
    it 'no toca los números de versión ni de producto' do
      frase = 'voy actualiza a firebird 5 kontrolya ya es comparble'

      expect(enmascarar(frase)).to eq(frase)
    end

    it 'no toca un año ni un número corto de documento' do
      frase = 'no puedo timbrar la factura A-1234 de CONTPAQi 2026'

      expect(enmascarar(frase)).to eq(frase)
    end

    it 'no confunde una fecha con un teléfono' do
      frase = 'desde el 2026-09-11 no puedo entrar'

      expect(enmascarar(frase)).to eq(frase)
    end

    it 'conserva los typos y la falta de acentos, que es lo que se vino a buscar' do
      frase = 'como puedo actualizar a la ultima version'

      expect(enmascarar(frase)).to eq(frase)
    end
  end

  describe 'bordes' do
    it 'no revienta con nil' do
      expect(enmascarar(nil)).to eq('')
    end

    it 'tapa varios datos en la misma frase' do
      resultado = enmascarar('soy juan@x.com, tel 5512345678, rfc GODE561231GR8')

      expect(resultado).to include('[correo]', '[telefono]', '[rfc]')
      expect(resultado).not_to include('juan@x.com', '5512345678', 'GODE561231GR8')
    end
  end
end
