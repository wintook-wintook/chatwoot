require 'rails_helper'

RSpec.describe ContactTrackings::PromptConstants do
  let(:texto) do
    <<~TXT
      [VARIABLES]
      SISTEMA = valor

      [DATOS FIJOS]
      EMPRESA = Kontrolya
      LIGA_AGENDA (liga) = https://kontrolya.com/agenda/
      Q1 (pregunta) = ¿Qué sistemas utilizas hoy? → guarda en SISTEMA
      CIERRE (texto) = Ahora que ya entendí 👌

        Puedes agendar aquí 👇 %LIGA_AGENDA%
      Nota que no es dato.

      [BIENVENIDA]
      Presenta a %EMPRESA% y haz %Q1%. Cierra con:
      %CIERRE%
      Ofrece 10% de beca y 20% después.
    TXT
  end

  describe '.parse' do
    it 'lee nombre, tipo, valor, a qué variable guarda y su línea' do
      c = described_class.parse(texto)
      expect(c.keys).to eq(%w[EMPRESA LIGA_AGENDA Q1 CIERRE])
      expect(c['Q1']).to include(type: 'pregunta', value: '¿Qué sistemas utilizas hoy?', saves_to: 'SISTEMA', line: 7)
      expect(c['LIGA_AGENDA'][:type]).to eq('liga')
      expect(c['EMPRESA'][:type]).to eq('texto')
    end

    it 'junta los renglones con sangría, con sus párrafos' do
      expect(described_class.parse(texto)['CIERRE'][:value])
        .to eq("Ahora que ya entendí 👌\n\nPuedes agendar aquí 👇 %LIGA_AGENDA%")
    end

    it 'acepta [CONSTANTES] y tipos en otras formas' do
      c = described_class.parse("[CONSTANTES]\nTOPE (número) = 5\nWEB (url) = https://x.mx")
      expect(c.transform_values { |v| v[:type] }).to eq('TOPE' => 'numero', 'WEB' => 'liga')
    end
  end

  describe '.expand' do
    subject(:expandido) { described_class.expand(texto) }

    it 'sustituye cada referencia, también dentro de otro dato fijo' do
      expect(expandido).to include('Presenta a Kontrolya y haz «¿Qué sistemas utilizas hoy?».')
      expect(expandido).to include("Ahora que ya entendí 👌\n\nPuedes agendar aquí 👇 https://kontrolya.com/agenda/")
    end

    it 'quita la sección y escribe la regla de la pregunta que guarda' do
      expect(expandido).not_to include('[DATOS FIJOS]')
      expect(expandido).not_to include('Nota que no es dato')
      expect(expandido).to include('[PREGUNTAS QUE GUARDAN UN DATO]')
      expect(expandido).to include('marca SISTEMA=<lo que contestó>')
      expect(expandido).to include("[VARIABLES]\nSISTEMA = valor")
    end

    it 'no toca los porcentajes ni lo que no está declarado' do
      expect(expandido).to include('Ofrece 10% de beca y 20% después.')
      expect(described_class.expand("[DATOS FIJOS]\nA = 1\n\n[X]\n%NO_EXISTE% y %A%")).to include('%NO_EXISTE% y 1')
    end

    it 'no cambia un texto sin datos fijos' do
      sin = "[ROL]\nEres el agente.\nOfrece 30% de beca."
      expect(described_class.expand(sin)).to equal(sin)
    end

    it 'una referencia circular no se cuelga' do
      expect(described_class.expand("[DATOS FIJOS]\nA = %B%\nB = %A%\n\n[X]\n%A%")).to be_a(String)
    end
  end

  describe 'ContactTracking#complementary_prompt' do
    it 'el motor lee el texto sustituido y la API el original' do
      tracking = ContactTracking.new(complementary_prompt: texto)
      expect(tracking.complementary_prompt).to include('Presenta a Kontrolya')
      expect(tracking.raw_complementary_prompt).to eq(texto)
    end

    it 'vuelve a sustituir si el texto cambia' do
      tracking = ContactTracking.new(complementary_prompt: texto)
      tracking.complementary_prompt
      tracking.complementary_prompt = texto.sub('Kontrolya', 'Wintook')
      expect(tracking.complementary_prompt).to include('Presenta a Wintook')
    end
  end
end
