# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — F1 de docs/importar_prompt_md_plan.md
RSpec.describe ContactTrackings::Assistant::BriefChunker do
  def trocear(texto) = described_class.call(texto)

  # Un corte "limpio" cae en un título o después de un renglón en blanco: nunca a la
  # mitad de un párrafo, que es donde vive una regla.
  def cortes_limpios?(texto, resultado)
    renglones = texto.split("\n", -1)
    resultado.chunks.drop(1).all? do |trozo|
      inicio = trozo.first_line - 1
      renglones[inicio - 1].strip.empty? || resultado.chunks.any? { |c| c.titles.any? } ||
        renglones[inicio].match?(/\A(#|\[|[A-ZÁÉÍÓÚÑ ]{3,}\z)/)
    end
  end

  # El banco de §2.1: objetivos y formas distintas. ADAM aparte (no va al repo).
  describe 'con el banco de encargos' do
    banco = {
      'citas_medicas' => %w[ROL ESTILO PROHIBIDO],
      'licencias_facturacion' => %w[ROL ETIQUETAS PROHIBIDO],
      'vendedor_catalogo' => ['ROL', 'BÚSQUEDA DE PRODUCTOS', 'PEDIDO'],
      'coordinador_operacion' => ['QUIEN ERES', 'SOPORTE', 'NO DIAGNOSTICAR'],
      'dci_v812' => ['ROL Y LÍMITES', '1. ROUTER', 'NODO CIERRE'],
      'vendedor_escuela' => ['QUIÉN ERES', 'MOTOR DE RUTAS', 'RUTA — OBJECIONES'],
      'cobranza' => ['QUIÉN ES', 'CUÁNDO PASA A UNA PERSONA', 'NUNCA', 'TONO'],
      'soporte_deriva' => []
    }

    banco.each do |nombre, temas|
      context nombre do
        let(:texto) { Rails.root.join("spec/fixtures/files/agent_briefs/#{nombre}.md").read }
        let(:resultado) { trocear(texto) }

        it 'da al menos un trozo y no pierde ni un carácter' do
          expect(resultado.chunks).not_to be_empty
          expect(resultado.chunks.map(&:text).join("\n")).to eq(texto)
        end

        it 'reconoce sus temas' do
          temas.empty? ? expect(resultado.outline).to(be_empty) : expect(resultado.outline).to(include(*temas))
        end

        it 'partido en trozos chicos, corta solo entre temas o párrafos' do
          stub_const("#{described_class}::MAX_CHARS", 1_200)
          chico = trocear(texto)

          expect(chico.chunks.map(&:text).join("\n")).to eq(texto)
          expect(cortes_limpios?(texto, chico)).to be(true)
        end
      end
    end

    it 'un encargo de una página es un solo trozo' do
      texto = Rails.root.join('spec/fixtures/files/agent_briefs/cobranza.md').read

      expect(trocear(texto).chunks.size).to eq(1)
    end
  end

  describe 'las señales de tema' do
    it 'usa la más marcada que haya: Markdown antes que corchetes' do
      texto = "## Uno\n[A]\nx\n## Dos\n[B]\ny"

      expect(trocear(texto)).to have_attributes(signal: :h2, outline: %w[Uno Dos])
    end

    it 'un título suelto arriba de todo es el nombre del documento' do
      texto = "# PROMPT DEL AGENTE\n\n[ROL]\nx\n[ESTILO]\ny"

      expect(trocear(texto)).to have_attributes(signal: :bracket, outline: %w[ROL ESTILO])
    end

    it 'reconoce títulos decorados' do
      texto = "=== OBJETIVO ===\nvender\n\n*** Tono ***\ncálido"

      expect(trocear(texto)).to have_attributes(signal: :decorated, outline: %w[OBJETIVO Tono])
    end

    it 'un renglón en MAYÚSCULAS es título solo si va suelto y no es una viñeta' do
      texto = "QUIÉN ES\nSofía.\nNUNCA GRITA\n\n- NO AMENAZA\n\nTONO:\nde usted"

      expect(trocear(texto).outline).to eq(['QUIÉN ES', 'TONO'])
    end

    it 'no lee títulos dentro de un bloque de código' do
      texto = "[ROL]\nx\n```\n[NO ES TEMA]\n```\n[ESTILO]\ny"

      expect(trocear(texto).outline).to eq(%w[ROL ESTILO])
    end

    # El Vendedor Escuela (#8533) está entero dentro de un ```text.
    it 'sí los lee si el bloque de código envuelve el documento entero' do
      texto = "```text\n# PROMPT\n\n[ROL]\nx\n[ESTILO]\ny\n```"

      expect(trocear(texto)).to have_attributes(signal: :bracket, outline: %w[ROL ESTILO])
    end
  end

  describe 'el tamaño de los trozos' do
    before { stub_const("#{described_class}::MAX_CHARS", 100) }

    it 'junta temas vecinos mientras quepan' do
      texto = (1..6).map { |n| "[T#{n}]\n#{'x' * 20}" }.join("\n") # 25 caracteres por tema

      expect(trocear(texto).chunks.map(&:titles)).to eq([%w[T1 T2 T3], %w[T4 T5 T6]])
    end

    it 'un tema demasiado grande se parte por sus subtemas, con su ruta' do
      texto = "# A\n#{'x' * 20}\n## A1\n#{'y' * 60}\n## A2\n#{'z' * 60}\n# B\nb"
      trozos = trocear(texto).chunks

      expect(trozos.map(&:path)).to eq([%w[A A1], %w[A A2], %w[B]])
      expect(trozos.first.text).to start_with("# A\n")
    end

    it 'sin títulos, parte por párrafos' do
      texto = Array.new(4) { |n| "párrafo #{n} #{'p' * 40}" }.join("\n\n")
      trozos = trocear(texto).chunks

      expect(trozos.size).to be > 1
      expect(trozos.map(&:text).join("\n")).to eq(texto)
      expect(trozos).to all(satisfy { |t| t.chars <= 100 })
    end

    it 'guarda la huella de cada trozo y no el texto' do
      trozo = trocear("[A]\nuno").chunks.first

      expect(trozo.to_h).to include(sha256: Digest::SHA256.hexdigest("[A]\nuno"), first_line: 1, last_line: 2)
      expect(trozo.to_h).not_to have_key(:text)
    end
  end

  adam = '/tmp/adam/ADAM-2.0-Comportamiento.md'
  describe 'ADAM (solo si el archivo está en el servidor)', if: File.exist?(adam) do
    let(:texto) { File.read(adam) }
    let(:resultado) { trocear(texto) }

    it 'lo parte por capítulos sin perder nada y sin pasarse del tamaño' do
      expect(resultado.signal).to eq(:h1)
      expect(resultado.outline).to include('C0 · CONSTITUCIÓN', 'C7 · PROTOCOLO COMERCIAL')
      expect(resultado.chunks.map(&:text).join("\n")).to eq(texto)
      expect(resultado.chunks.map(&:chars).max).to be <= described_class::MAX_CHARS
      expect(cortes_limpios?(texto, resultado)).to be(true)
    end
  end
end
