# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — preguntas en orden → [VARIABLES] + [DATOS FIJOS] + uso.
RSpec.describe ContactTrackings::Ficha::Questions do
  let(:base) do
    <<~TXT.strip
      @ruta(info #info: pregunta algo): @buscar_articulo

      [ALCANCE POR RAMA]
      info: Contesto con los artículos.

      [DATOS FIJOS]
      EMPRESA = Kontrolya

      [VARIABLES]
      ETAPA = NUEVO | CLIENTE
    TXT
  end
  let(:preguntas) do
    described_class.clean([{ 'text' => '¿Qué sistema usas?', 'var' => 'sistema', 'options' => %w[CONTPAQi Aspel] },
                           { 'text' => '¿Cuántos usuarios?', 'var' => '' }, { 'text' => '  ' }])
  end

  it 'limpia: sin preguntas vacías y con nombre de variable' do
    expect(preguntas).to eq([{ 'text' => '¿Qué sistema usas?', 'var' => 'SISTEMA', 'options' => %w[CONTPAQi Aspel] },
                             { 'text' => '¿Cuántos usuarios?', 'var' => 'RESPUESTA_2', 'options' => [] }])
  end

  it 'se lee igual que se escribió' do
    texto = described_class.new(base).write(preguntas, 'start').text
    expect(described_class.new(texto).read).to include(when: 'start')
  end

  it 'escribe al inicio sin tocar lo demás y reescribir no duplica' do
    texto = described_class.new(base).write(preguntas, 'start').text

    expect(texto).to include('EMPRESA = Kontrolya', 'ETAPA = NUEVO | CLIENTE', 'SISTEMA = CONTPAQi | Aspel', 'RESPUESTA_2 = valor')
    expect(texto).to include('Q1 (pregunta) = ¿Qué sistema usas? → guarda en SISTEMA', '[PREGUNTAS]')

    otra = described_class.new(texto).write(preguntas.first(1), 'info').text
    expect(otra.scan('(pregunta)').size).to eq(1)
    expect(otra).not_to include('[PREGUNTAS]', 'RESPUESTA_2')
    expect(otra).to include('info: Contesto con los artículos. Antes de contestar, pregunto una a la vez y en este orden: %Q1%')
    expect(described_class.new(otra).read[:when]).to eq('info')
    expect(ContactTrackings::Assistant::ValidatorService.new(otra, account: create(:account)).call[:blocking]).to eq([])
  end

  context 'with la bienvenida' do
    it 'la primera pregunta va al final del texto de la bienvenida, antes de sus archivos' do
      con = "#{base}\n\n[MENSAJE DE BIENVENIDA]\n¡Hola! Soy Ana.\n{{catalogo}}"
      texto = described_class.new(con).write(preguntas, 'welcome').text

      expect(ContactTrackings::WelcomeMessage.text(texto)).to eq("¡Hola! Soy Ana.\n¿Qué sistema usas?\n{{catalogo}}")
      expect(texto).to include('[PREGUNTAS]')
      expect(described_class.new(texto).read[:when]).to eq('welcome')
    end

    it 'sin bienvenida, la conversación arranca con la primera pregunta' do
      texto = described_class.new(base).write(preguntas, 'welcome').text
      expect(ContactTrackings::WelcomeMessage.text(texto)).to eq('¿Qué sistema usas?')
      expect(ContactTrackings::Assistant::ValidatorService.new(texto, account: create(:account)).call[:blocking]).to eq([])
    end

    it 'al cambiar de opción la pregunta sale de la bienvenida y la sección vacía se quita' do
      texto = described_class.new(base).write(preguntas, 'welcome').text
      otra = described_class.new(texto).write(preguntas, 'start').text

      expect(ContactTrackings::WelcomeMessage.text(otra)).to be_nil
      expect(described_class.new(otra).read[:when]).to eq('start')
    end

    it 'la bienvenida que se edita no trae la pregunta' do
      con = "#{base}\n\n[MENSAJE DE BIENVENIDA]\n¡Hola!"
      texto = described_class.new(con).write(preguntas, 'welcome').text
      lectura = described_class.new(texto).read
      expect(described_class.welcome_without("¡Hola!\n¿Qué sistema usas?", lectura)).to eq('¡Hola!')
    end
  end
end
