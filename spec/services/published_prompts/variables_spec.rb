# frozen_string_literal: true

require 'rails_helper'

# proyecto@adaptar_prompts_publicados (F4)
RSpec.describe PublishedPrompts::Variables do
  let(:negocio) { { 'text' => 'Grúas del Norte', 'label' => 'Nombre del negocio' } }

  describe '.apply' do
    it 'cambia cada aparición en la prosa por la marca, sin distinguir mayúsculas' do
      texto = "Eres el asistente de Grúas del Norte.\nDespídete como GRÚAS DEL NORTE."

      expect(described_class.apply(texto, [negocio])).to eq(
        "Eres el asistente de <PENDIENTE: Nombre del negocio>.\nDespídete como <PENDIENTE: Nombre del negocio>."
      )
    end

    it 'no toca directivas, líneas @ruta ni otras marcas' do
      texto = "@ruta(ventas: precios de Grúas del Norte): {{doc:Grúas del Norte}} -> @crear_ticket(tipo=Grúas del Norte)\n" \
              'Usa @buscar_foro(Grúas del Norte). Somos Grúas del Norte. <PENDIENTE: Grúas del Norte>'

      expect(described_class.apply(texto, [negocio])).to eq(
        "@ruta(ventas: precios de Grúas del Norte): {{doc:Grúas del Norte}} -> @crear_ticket(tipo=Grúas del Norte)\n" \
        'Usa @buscar_foro(Grúas del Norte). Somos <PENDIENTE: Nombre del negocio>. <PENDIENTE: Grúas del Norte>'
      )
    end

    it 'el texto más largo gana, y una marca recién puesta no se vuelve a reemplazar' do
      corto = { 'text' => 'Grúas', 'label' => 'Lo que vendes' }
      negocio_largo = { 'text' => 'Grúas del Norte', 'label' => 'Grúas, nombre' }
      texto = 'Grúas del Norte vende Grúas.'

      expect(described_class.apply(texto, [corto, negocio_largo])).to eq(
        '<PENDIENTE: Grúas, nombre> vende <PENDIENTE: Lo que vendes>.'
      )
    end
  end

  # feat/reemplazo_directo_variables
  describe '.apply con valor' do
    it 'escribe el valor directo, sin marca' do
      con_valor = negocio.merge('value' => 'Grúas del Sur')

      expect(described_class.apply('Somos Grúas del Norte. {{doc:Grúas del Norte}}', [con_valor]))
        .to eq('Somos Grúas del Sur. {{doc:Grúas del Norte}}')
    end

    it 'un texto corto no se vuelve a reemplazar dentro del valor que dejó uno largo' do
      lista = [{ 'text' => 'Grúas', 'label' => 'a', 'value' => 'Autos' },
               { 'text' => 'Grúas del Norte', 'label' => 'b', 'value' => 'Grúas del Sur' }]

      expect(described_class.apply('Grúas del Norte vende Grúas.', lista)).to eq('Grúas del Sur vende Autos.')
    end

    it 'no toca la llave de una ruta en [ALCANCE POR RAMA] ni las #etiquetas' do
      texto = "- kontrolya: Presenta Kontrolya.
#interes-kontrolya = interés en Kontrolya."
      lista = [{ 'text' => 'Kontrolya', 'label' => 'Producto', 'value' => 'MiTablero' }]

      expect(described_class.apply(texto, lista))
        .to eq("- kontrolya: Presenta MiTablero.
#interes-kontrolya = interés en MiTablero.")
    end
  end

  describe '.count' do
    it 'cuenta solo en la prosa' do
      expect(described_class.count('Grúas del Norte y {{doc:Grúas del Norte}}', 'grúas del norte')).to eq(1)
    end
  end

  describe '.normalize' do
    it 'quita vacías y repetidas, y limpia espacios' do
      lista = [{ text: '  Grúas  del Norte ', label: ' Nombre ' }, { text: 'grúas del norte', label: 'Otro' }, { text: '', label: 'x' }]

      expect(described_class.normalize(lista)).to eq([{ 'text' => 'Grúas del Norte', 'label' => 'Nombre' }])
    end

    it 'conserva el valor solo si trae algo' do
      lista = [{ text: 'Grúas', label: 'N', value: ' Autos ' }, { text: 'Horario', label: 'H', value: '' }]

      expect(described_class.normalize(lista)).to eq([{ 'text' => 'Grúas', 'label' => 'N', 'value' => 'Autos' },
                                                      { 'text' => 'Horario', 'label' => 'H' }])
    end
  end

  describe '.problems' do
    around { |example| I18n.with_locale(:es) { example.run } }

    it 'avisa lo que no se puede publicar' do
      lista = [
        { 'text' => 'ab', 'label' => 'Corto' },
        { 'text' => 'Horario', 'label' => '' },
        { 'text' => 'Teléfono', 'label' => 'Teléfono' },
        { 'text' => 'Precios', 'label' => 'Precios' }
      ]
      problemas = described_class.problems(lista, 'Horario: siempre. Usa {{doc:Precios}}.')

      expect(problemas.size).to eq(4)
      expect(problemas.last).to include('«Precios» no aparece en el Entrenamiento')
    end

    it 'un valor que es otra marca no pasa' do
      problemas = described_class.problems([negocio.merge('value' => '<PENDIENTE: X>')], 'Somos Grúas del Norte.')

      expect(problemas.first).to include('Grúas del Norte')
    end

    it 'sin problemas, nada' do
      expect(described_class.problems([negocio], 'Somos Grúas del Norte.')).to eq([])
    end
  end
end
