# frozen_string_literal: true

require 'rails_helper'

# proyecto@crear_agente_conversando F3 — lo que el chat llena aparte, al formato del motor.
RSpec.describe ContactTrackings::Assistant::DraftingFields do
  describe '.variables_text' do
    it 'escribe la sección como la leen el motor y el modal' do
      texto = described_class.variables_text([
                                               { 'nombre' => 'Sistema actual', 'valores' => %w[CONTPAQi Aspel], 'inicial' => 'aspel' },
                                               { 'nombre' => 'CORREO', 'libre' => true },
                                               { 'nombre' => 'ETAPA', 'valores' => 'NUEVO | CALIFICADO', 'inicial' => 'NUEVO' }
                                             ])

      expect(texto).to eq("SISTEMA_ACTUAL = CONTPAQi | Aspel\nCORREO = valor\nETAPA = NUEVO | CALIFICADO\n" \
                          'Inicial: SISTEMA_ACTUAL=Aspel; ETAPA=NUEVO')
      definicion = ContactTrackings::ConversationVariables::Definition.parse("[VARIABLES]\n#{texto}")
      expect(definicion.names).to include('SISTEMA_ACTUAL', 'CORREO', 'ETAPA')
    end

    it 'descarta un inicial que no es uno de los valores, nombres repetidos y lo que no sirve' do
      texto = described_class.variables_text([{ 'nombre' => 'ETAPA', 'valores' => %w[A B], 'inicial' => 'Z' },
                                              { 'nombre' => 'etapa', 'valores' => %w[C] }, 'basura', { 'nombre' => '123' }])

      expect(texto).to eq('ETAPA = A | B')
    end

    it 'sin nada que sirva es nil (no cambió)' do
      expect(described_class.variables_text([])).to be_nil
      expect(described_class.variables_text(nil)).to be_nil
    end
  end

  describe '.constants_text' do
    it 'escribe [DATOS FIJOS] que PromptConstants lee igual' do
      texto = described_class.constants_text([
                                               { 'nombre' => 'EMPRESA', 'tipo' => 'texto', 'contenido' => 'Kontrolya' },
                                               { 'nombre' => 'q1', 'tipo' => 'pregunta', 'contenido' => '¿Qué sistema usas?',
                                                 'guarda_en' => 'sistema' },
                                               { 'nombre' => 'LIGA', 'tipo' => 'link', 'contenido' => 'https://k.mx' },
                                               { 'nombre' => 'CIERRE', 'contenido' => "Gracias.\n\nAgenda aquí %LIGA%" }
                                             ])

      leidas = ContactTrackings::PromptConstants.parse("[DATOS FIJOS]\n#{texto}")
      expect(leidas.keys).to eq(%w[EMPRESA Q1 LIGA CIERRE])
      expect(leidas['Q1']).to include(type: 'pregunta', value: '¿Qué sistema usas?', saves_to: 'SISTEMA')
      expect(leidas['LIGA']).to include(type: 'liga')
      expect(leidas['CIERRE'][:value]).to eq("Gracias.\n\nAgenda aquí %LIGA%")
    end

    it 'un dato sin contenido no se escribe' do
      expect(described_class.constants_text([{ 'nombre' => 'EMPRESA', 'contenido' => ' ' }])).to be_nil
    end
  end

  describe '.from_reply' do
    it 'solo trae lo que cambió, con la Definición en las columnas del agente' do
      campos = described_class.from_reply('definicion' => { 'objetivo' => 'Agendar demos', 'contexto' => '' },
                                          'variables' => nil, 'datos_fijos' => [{ 'nombre' => 'EMPRESA', 'contenido' => 'K' }])

      expect(campos).to eq('objective' => 'Agendar demos', 'datos_fijos' => 'EMPRESA = K')
    end
  end
end
