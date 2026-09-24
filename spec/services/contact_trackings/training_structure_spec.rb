# frozen_string_literal: true

# proyecto@asistente_agentes_ia — plan: docs/formulario_entrenamiento_plan.md
require 'rails_helper'

RSpec.describe ContactTrackings::TrainingStructure do
  def bloques(texto)
    described_class.parse(texto)['blocks']
  end

  def resumen(texto)
    bloques(texto).map { |b| b['type'] == 'section' ? "#{b['style']}:#{b['title']}" : b['type'] }
  end

  # El invariante del plan: abrir un agente en el formulario y guardarlo sin tocar
  # nada no cambia ni un carácter de lo que lee el motor. Medido además sobre los 28
  # prompts reales del respaldo del 11/09/2026 (45 de 45 con estos sintéticos).
  describe 'ida y vuelta' do
    [
      '', "\n", 'A', "A\n", "\n\nA", '[ROL]', "[ROL]\n",
      "[ROL]\n\nx\n\n\n[EST]\ny",
      "# Título\n\n## A\nx\n### sub\ny\n\n## B\nz\n",
      "@ruta(a #aaa: x): -\n\n@ruta(b #bbb: y): -\n@ruta_por_defecto: a\n\n[ROL]\ntexto\n@ruta(c #ccc: z): -\nmas",
      "```\n## no es\n```\n## si es\nx",
      "## PERSONALIDAD ##\n* uno\n\n---\n\n## FORMATO\n* dos",
      "Texto corrido sin ninguna sección.\nOtra línea."
    ].each do |texto|
      it "rearma idéntico #{texto.inspect.truncate(50)}" do
        expect(described_class.compose(described_class.parse(texto))).to eq(texto)
      end
    end
  end

  describe 'qué es cada bloque' do
    it 'separa ramas, texto inicial y secciones' do
      texto = "@ruta(a #aaa: x): -\n@ruta_por_defecto: a\n\nPROMPT DE CITAS\n\n[ROL]\nSos amable.\n\n[ESTILO]\nBreve."

      expect(resumen(texto)).to eq(['routes', 'preamble', 'bracket:ROL', 'bracket:ESTILO'])
    end

    # 8 de 28 prompts medidos no tienen secciones: se abren igual, todo como texto inicial.
    it 'un prompt sin secciones es un solo bloque de texto inicial' do
      expect(resumen("Sos un asesor.\nContestá breve.")).to eq(['preamble'])
    end

    # 7 de 28 usan Markdown y 6 mezclan los dos formatos.
    it 'reconoce encabezados Markdown y conserva el estilo' do
      expect(resumen("## PERSONALIDAD\nx\n\n[ROL]\ny")).to eq(['markdown2:PERSONALIDAD', 'bracket:ROL'])
    end

    it 'toma como sección el nivel más alto y deja los subtítulos dentro' do
      bloque = bloques("## REGLA\nintro\n### A. COINCIDENCIA EXACTA\ndetalle").first

      expect(bloque).to include('title' => 'REGLA', 'body' => "intro\n### A. COINCIDENCIA EXACTA\ndetalle")
    end

    it 'un único # al principio es el título del prompt, no una sección' do
      expect(resumen("# AGENTE DE CITAS\n\n## ROL\nx")).to eq(['preamble', 'markdown2:ROL'])
    end

    it 'una rama mal escrita va con las demás ramas, no escondida en una sección' do
      texto = "@ruta(info #info: ¿qué hacen?)\n@ruta(a #aaa: x): -\n\n[ROL]\nAmable."
      rutas = bloques(texto).first

      expect(resumen(texto)).to eq(['routes', 'bracket:ROL'])
      expect(rutas['lines'].pluck('kind')).to eq(%w[broken route])
    end

    it 'no confunde una etiqueta #soporte con un encabezado' do
      expect(resumen("[ETIQUETAS]\n#soporte1 para soporte")).to eq(['bracket:ETIQUETAS'])
    end
  end

  describe 'armar lo que cambió el formulario' do
    let(:estructura) { described_class.parse("[ROL]\nSos amable.\n\n## ESTILO\nBreve.\n") }

    it 'cambia solo el cuerpo editado' do
      estructura['blocks'][0]['body'] = 'Sos el asistente del consultorio.'

      expect(described_class.compose(estructura)).to eq("[ROL]\nSos el asistente del consultorio.\n\n## ESTILO\nBreve.\n")
    end

    it 'separa con un renglón en blanco una sección nueva aunque la anterior no terminara en uno' do
      pegado = described_class.parse("[ROL]\nSos amable.")
      pegado['blocks'] << { 'type' => 'section', 'title' => 'ESTILO', 'body' => 'Breve.' }

      expect(described_class.compose(pegado)).to eq("[ROL]\nSos amable.\n\n[ESTILO]\nBreve.")
    end

    it 'agrega una sección nueva con formato [TÍTULO]' do
      estructura['blocks'] << { 'type' => 'section', 'title' => 'NO SIMULAR', 'body' => 'Nunca confirmes sin confirmar.' }

      expect(described_class.compose(estructura)).to end_with("Breve.\n\n[NO SIMULAR]\nNunca confirmes sin confirmar.")
    end

    it 'renombra una sección conservando su estilo' do
      estructura['blocks'][1]['title'] = 'TONO'

      expect(described_class.compose(estructura)).to include("## TONO\nBreve.")
    end

    it 'borra y reordena' do
      estructura['blocks'].reverse!
      estructura['blocks'].pop

      expect(described_class.compose(estructura)).to eq("## ESTILO\nBreve.\n")
    end

    # Un título así rompería el rótulo y la sección se partiría al volver a leerla.
    it 'limpia corchetes y saltos de línea del título' do
      estructura['blocks'][0]['title'] = "RO[L]\nx"

      expect(described_class.compose(estructura)).to start_with("[RO L x]\n")
    end

    it 'ignora bloques de un tipo desconocido' do
      estructura['blocks'] << { 'type' => 'inventado', 'text' => 'nada' }

      expect(described_class.compose(estructura)).not_to include('nada')
    end
  end
end
