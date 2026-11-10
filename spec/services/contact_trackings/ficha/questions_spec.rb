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
end
