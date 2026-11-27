# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — datos fijos del negocio, citados en [DATOS DEL NEGOCIO].
RSpec.describe ContactTrackings::Ficha::BusinessData do
  let(:base) do
    <<~TXT.strip
      @ruta(info #info: pregunta algo): @buscar_articulo

      [DATOS FIJOS]
      Q1 (pregunta) = ¿Ciudad? → guarda en CIUDAD
      EMPRESA = Otra cosa escrita a mano
    TXT
  end
  let(:datos) do
    described_class.clean([{ 'label' => 'Empresa', 'value' => 'Kontrolya' }, { 'label' => 'Liga para agendar:', 'value' => 'https://k.mx/agenda' },
                           { 'label' => 'Vacío', 'value' => ' ' }, { 'label' => 'empresa', 'value' => 'repetida' }])
  end

  it 'limpia, escribe sin chocar con otros datos fijos y se lee igual' do
    expect(datos).to eq([{ 'label' => 'Empresa', 'value' => 'Kontrolya' }, { 'label' => 'Liga para agendar', 'value' => 'https://k.mx/agenda' }])
    texto = described_class.new(base).write(datos).text

    expect(texto).to include('EMPRESA = Otra cosa escrita a mano', 'EMPRESA_2 = Kontrolya',
                             'LIGA_PARA_AGENDAR (liga) = https://k.mx/agenda',
                             "[DATOS DEL NEGOCIO]\n- Empresa: %EMPRESA_2%\n- Liga para agendar: %LIGA_PARA_AGENDAR%")
    expect(described_class.new(texto).read.map { |d| d.slice('label', 'value') }).to eq(datos)
    hallazgos = ContactTrackings::Assistant::ValidatorService.new(texto, account: create(:account)).call
    expect(hallazgos[:blocking]).to eq([])
  end

  it 'reescribir reemplaza y vacío los quita (sin tocar lo ajeno)' do
    texto = described_class.new(base).write(datos).text
    otra = described_class.new(texto).write([{ 'label' => 'Teléfono', 'value' => '81 1234' }]).text
    expect(otra).to include('TELEFONO = 81 1234', '- Teléfono: %TELEFONO%', 'Q1 (pregunta)')
    expect(otra).not_to include('Kontrolya', 'LIGA_PARA_AGENDAR')

    sin = described_class.new(otra).write([]).text
    expect(sin).not_to include('DATOS DEL NEGOCIO', 'TELEFONO')
    expect(sin).to include('EMPRESA = Otra cosa escrita a mano')
  end
end
