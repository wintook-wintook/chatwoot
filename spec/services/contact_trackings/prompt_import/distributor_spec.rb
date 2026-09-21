# frozen_string_literal: true

require 'rails_helper'

# proyecto@importar_prompt_md — F1 (docs/importar_prompt_md_plan.md §4.2)
RSpec.describe ContactTrackings::PromptImport::Distributor do
  let(:account) { create(:account) }
  let(:markdown) do
    [section('Identidad', chapter: 'C0 · CONSTITUCIÓN'),
     section('Precios en esta etapa — Los costos no son públicos'),
     section('Seguimiento — La secuencia de tres contactos y el cierre elegante'),
     section('Guion: páginas web'),
     section('Branding®', chapter: 'C6 · OFERTA'),
     section('Forma de aprender', chapter: 'C1 · CARÁCTER')].join("\n")
  end

  def section(title, rules: 1, chapter: 'C7 · PROTOCOLO COMERCIAL', description: 'Descripción.')
    reglas = Array.new(rules) do |i|
      "**X#{title.sum}-01.#{i + 1}** (inviolable) — Regla #{i + 1}.\n  - Prompt: Regla corta #{i + 1}.\n"
    end
    "# #{chapter}\n\n## #{title}\n\n#{description}\n\n### Norma\n\n#{reglas.join("\n")}\n"
  end

  def read(markdown)
    ContactTrackings::PromptImport::Reader.call(markdown)
  end

  def unit(result, title)
    result.units.find { |u| u.title == title }
  end

  describe 'solo reglas fijas' do
    subject(:result) { described_class.new(read(markdown), use_ai: false).call }

    it 'reparte por el título principal, sin el subtítulo después de "—"' do
      expect(unit(result, 'Identidad').to_h).to include(destination: 'section', hint: 'ROL', source: :fixed)
      expect(unit(result, 'Precios en esta etapa — Los costos no son públicos').to_h)
        .to include(destination: 'route', hint: 'precios')
      expect(unit(result, 'Guion: páginas web').destination).to eq('script')
      expect(unit(result, 'Branding®').to_h).to include(destination: 'knowledge', hint: 'servicio')
      # "cierre" está en el subtítulo: no la manda a la ruta de reunión.
      expect(unit(result, 'Seguimiento — La secuencia de tres contactos y el cierre elegante').to_h)
        .to include(destination: 'section', source: :default)
      expect(result.ai).to eq(status: :skipped)
    end

    it 'cada unidad lleva sus reglas y ejemplos para que la IA la juzgue sin leer el texto' do
      identidad = unit(result, 'Identidad')
      expect(identidad.rule_ids.size).to eq(1)
      expect(identidad.samples).to eq(['Regla corta 1.'])
      expect(identidad.excerpt).to eq('Descripción.')
    end
  end

  describe 'con la revisión de la IA' do
    let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, api_key: 'sk-x') }

    before { allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat) }

    def keyed(title)
      unit(described_class.new(read(markdown), use_ai: false).call, title).key
    end

    def answer(title, **fields)
      { 'key' => keyed(title), 'motivo' => "motivo de #{title}" }.merge(fields.transform_keys(&:to_s))
    end

    it 'decide lo que las reglas fijas no reconocieron, y puede sacar del prompt lo que sí' do
      allow(chat).to receive(:call).and_return('units' => [
                                                 answer('Seguimiento — La secuencia de tres contactos y el cierre elegante',
                                                        quien: 'automatico'),
                                                 answer('Forma de aprender', quien: 'sistema'),
                                                 answer('Identidad', quien: 'agente', cuando: 'tema', tema: 'quien_eres'),
                                                 answer('Branding®', quien: 'agente', cuando: 'tema', tema: 'branding')
                                               ])
      result = described_class.new(read(markdown), account: account).call

      expect(unit(result, 'Seguimiento — La secuencia de tres contactos y el cierre elegante').to_h)
        .to include(destination: 'out', source: :ai, fixed: 'section')
      expect(unit(result, 'Forma de aprender').destination).to eq('out')
      # Lo que las reglas fijas reconocieron no se mueve (salvo a "out"): la IA solo da su motivo.
      expect(unit(result, 'Identidad').to_h).to include(destination: 'section', hint: 'ROL', reason: 'motivo de Identidad')
      expect(unit(result, 'Branding®').destination).to eq('knowledge')
      expect(result.ai).to eq(status: :ok, changed: 2)
    end

    it 'a una unidad sin regla fija le pone el destino y la pista que dijo la IA' do
      allow(chat).to receive(:call).and_return('units' => [
                                                 answer('Forma de aprender', quien: 'agente', cuando: 'siempre',
                                                                             seccion: '[Estilo]')
                                               ])

      expect(unit(described_class.new(read(markdown), account: account).call, 'Forma de aprender').to_h)
        .to include(destination: 'section', hint: 'ESTILO', source: :default)
    end

    it 'ignora respuestas sobre unidades que no existen o con valores desconocidos' do
      allow(chat).to receive(:call).and_return('units' => [{ 'key' => 'u999', 'quien' => 'persona' },
                                                           answer('Forma de aprender', quien: 'marciano')])
      result = described_class.new(read(markdown), account: account).call

      expect(unit(result, 'Forma de aprender').destination).to eq('section')
      expect(result.ai).to eq(status: :ok, changed: 0)
    end

    it 'sin respuesta de la IA queda el reparto de las reglas fijas y lo avisa' do
      allow(chat).to receive(:call).and_return(nil)

      result = described_class.new(read(markdown), account: account).call
      expect(result.ai).to eq(status: :failed)
      expect(unit(result, 'Identidad').destination).to eq('section')
    end
  end

  it 'sin integración de OpenAI no llama y lo avisa' do
    result = described_class.new(read(markdown), account: account).call

    expect(result.ai).to eq(status: :no_api_key)
  end

  it 'un prompt común (sin reglas) se reparte por sus títulos de primer y segundo nivel' do
    generic = read(Rails.root.join('spec/fixtures/files/prompt_import/generico.md').read)
    result = described_class.new(generic, use_ai: false).call

    expect(result.units.map { |u| [u.title, u.destination, u.hint] })
      .to eq([['Agente de ventas', 'section', nil], %w[Reglas section PRINCIPIOS], %w[Estilo section CONVERSACION]])
  end

  it 'marca como pruebas los casos de aplicación práctica y deja fuera la portada' do
    md = "# Portada\n\nCréditos.\n\n#{section('Identidad', chapter: 'C0 · X')}\n#### Aplicación práctica\n\n##### Caso 1\n\nEjemplo.\n"
    result = described_class.new(read(md), use_ai: false).call

    expect(result.tests.size).to eq(2)
    expect(result.out_blocks).to eq([0])
  end
end
