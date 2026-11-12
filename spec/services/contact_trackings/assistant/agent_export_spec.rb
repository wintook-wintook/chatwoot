# frozen_string_literal: true

require 'rails_helper'

# proyecto@crear_agente_conversando F4 — el .md para pegar en otra IA.
RSpec.describe ContactTrackings::Assistant::AgentExport do
  let(:entrenamiento) do
    "[VARIABLES]\nSISTEMA = CONTPAQi | Aspel | Otro\nCORREO = valor\nInicial: SISTEMA=Aspel\n\n" \
      "[DATOS FIJOS]\nEMPRESA = Kontrolya\nQ1 (pregunta) = ¿Qué sistema usas? → guarda en SISTEMA\n\n" \
      "[BIENVENIDA]\nPresenta a %EMPRESA% y haz %Q1%.\n@ruta(demo #demo: quiero una demo): - -> @agendar_calendar"
  end

  it 'con Entrenamiento: aviso, Definición, variables en palabras y los datos fijos sustituidos' do
    resultado = described_class.new(name: 'Kontrolya demos', draft: entrenamiento,
                                    fields: { 'objective' => 'Agendar demos', 'ai_context' => 'Vende software' }).call
    texto = resultado[:content]

    expect(resultado[:filename]).to eq('instrucciones_kontrolya_demos.md')
    expect(texto).to start_with("# Instrucciones del agente: Kontrolya demos\n\n> Este archivo salió del sistema")
    expect(texto).to include("## Objetivo\n\nAgendar demos", "## Contexto\n\nVende software")
    expect(texto).to include('- **SISTEMA**: uno de CONTPAQi, Aspel o Otro. Empieza en Aspel.',
                             '- **CORREO**: lo que escriba el cliente')
    expect(texto).to include('Presenta a Kontrolya y haz «¿Qué sistema usas?».', '@ruta(demo #demo: quiero una demo)')
    expect(texto).not_to include('%EMPRESA%', '[DATOS FIJOS]')
  end

  it 'sin Entrenamiento: las instrucciones iniciales un nivel abajo y los datos fijos en lista' do
    texto = described_class.new(name: 'Leo', instructions: "# Instrucciones iniciales: Leo\n\n## Quién es\nLeo, asesor",
                                fields: { 'datos_fijos' => 'Q1 (pregunta) = ¿Qué usas? → guarda en SISTEMA',
                                          'variables' => 'SISTEMA = A | B' }).call[:content]

    expect(texto).to include("## Instrucciones iniciales\n\n### Quién es\nLeo, asesor",
                             '- **Q1** — pregunta: ¿Qué usas? (la respuesta se recuerda en SISTEMA)', '- **SISTEMA**: uno de A o B')
    expect(texto).not_to include('# Instrucciones iniciales: Leo')
  end

  it 'sin nada más que el nombre, solo el título y el aviso' do
    texto = described_class.new(name: '').call[:content]

    expect(texto.scan(/^## /)).to be_empty
    expect(texto).to start_with('# Instrucciones del agente: agente')
  end
end
