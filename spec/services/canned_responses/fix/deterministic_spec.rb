# frozen_string_literal: true

require 'rails_helper'

# proyecto@arreglar_predefinidas — las piezas sin IA, con textos de giros distintos.
RSpec.describe 'Arreglar predefinidas sin IA' do # rubocop:disable RSpec/DescribeClass
  describe CannedResponses::Fix::Cleanup do
    it 'quita imágenes incrustadas, HTML, entidades y párrafos repetidos sin tocar los datos' do
      texto = "🌐 <https://dapsagro.mx/>\n\n![logo](data:image/png;base64,#{'A' * 500}==)\n\n" \
              "Matriz<br>Lunes a viernes&nbsp;8:00 a 14:00 <a href=\"https://wa.me/523\">WhatsApp</a>\n\n\n\n" \
              "Sucursal norte con horario extendido\n\nSucursal norte con horario extendido"

      resultado = described_class.call(texto)

      expect(resultado.content).to eq("🌐 <https://dapsagro.mx/>\n\nMatriz\nLunes a viernes 8:00 a 14:00 WhatsApp (https://wa.me/523)\n\n" \
                                      'Sucursal norte con horario extendido')
      expect(resultado.removed.pluck('kind')).to eq(%w[image_data html entities duplicates spaces])
    end

    it 'un texto limpio queda igual' do
      expect(described_class.call("Paso 1. Abre el menú.\n\nPaso 2. Guarda.").removed).to eq([])
    end
  end

  describe CannedResponses::Fix::HardData do
    let(:texto) do
      'Cuesta $ 1,500 al mes (10% de beca). Llama al 55 6857 4646 o a info@x.mx. Ver https://www.x.mx/alta. ' \
        'Dura 3 años, 9 cuatrimestres. Clave LIC-DER, RVOE 20181311. De 9:00 a 18:30, desde el 3 de mayo. ' \
        'Hola {{contact.name}}. Actualiza de 2024 a 2025 siga los pasos.'
    end

    it 'saca los datos duros de cualquier texto' do
      expect(described_class.extract(texto).map { |d| [d['kind'], d['text']] }).to include(
        ['money', '$ 1,500'], %w[percent 10%], ['phone', '55 6857 4646'], %w[email info@x.mx], %w[code LIC-DER],
        ['quantity', '3 años'], ['quantity', '9 cuatrimestres'], %w[number 20181311], %w[time 18:30],
        ['date', '3 de mayo'], %w[variable {{contact.name}}], %w[url https://www.x.mx/alta]
      )
    end

    it 'un año seguido de una palabra no es una cantidad' do
      expect(described_class.extract(texto).pluck('text')).not_to include('2025 siga')
    end

    it 'reconoce el mismo dato escrito de otra forma y señala el que cambió' do
      igual = ['Cuesta $1500 al mes, 10 % de beca. Tel 5568574646, info@x.mx, x.mx/alta',
               'Dura 3 años y 9 cuatrimestres. LIC-DER, RVOE 20181311, de 9:00 a 18:30 desde el 3 de mayo. ' \
               '{{contact.name}} 2024 2025']
      expect(described_class.missing(texto, igual)).to eq([])

      expect(described_class.missing(texto, ['Cuesta $1,800. Dura 4 años.']).pluck('text')).to include('$ 1,500', '3 años')
    end
  end

  describe CannedResponses::Fix::Rebalance do
    let(:texto) { "Intro corta.\n\n#{'palabra ' * 300}\n\n#{'Otra frase larga. ' * 150}" }

    it 'parte en bloques bajo el tope sin perder ni una palabra' do
      partes, mapa = described_class.call([{ 'short_code' => 'Guía', 'content' => texto }], 1900)

      expect(partes.map { |p| CannedResponse.agent_text(p['short_code'], p['content']).size }).to all(be <= 1900)
      expect(partes.flat_map { |p| p['content'].split }.sort).to eq(texto.split.sort)
      expect(partes.first['short_code']).to eq('Guía')
      expect(partes.drop(1).pluck('short_code')).to all(start_with('Guía (continuación'))
      expect(mapa).to eq(0 => 0)
    end

    it 'nunca repite un nombre, aunque la IA ya haya usado «(continuación)»' do
      partes, = described_class.call([{ 'short_code' => 'A', 'content' => 'x ' * 1200 },
                                      { 'short_code' => 'A (continuación)', 'content' => 'y' }], 1900)

      expect(partes.map { |p| p['short_code'].downcase }.uniq.size).to eq(partes.size)
    end

    it 'lo que ya cabe no se toca' do
      expect(described_class.call([{ 'short_code' => 'A', 'content' => 'corto' }], 1900).first)
        .to eq([{ 'short_code' => 'A', 'content' => 'corto' }])
    end
  end

  describe CannedResponses::Fix::Groups do
    let(:account) { create(:account) }

    before do
      directivas = 'Usa @buscar_predefinidas(SOPORTE) y @buscar_predefinidas(Fichas) y @buscar_predefinidas(!INTERNO)'
      create(:tracking_template, account: account, complementary_prompt: directivas)
    end

    it 'exige el prefijo que usan los agentes, pero no una categoría (la heredan las partes)' do
      grupos = described_class.new(account)

      expect(grupos.required_prefixes('SOPORTE Alta de empresa')).to eq(['SOPORTE'])
      expect(grupos.required_prefixes('Fichas de licencias')).to eq([])
      expect(grupos.required_prefixes('INTERNO notas')).to eq([])
    end
  end
end
