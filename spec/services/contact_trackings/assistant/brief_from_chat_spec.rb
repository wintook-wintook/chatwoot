# frozen_string_literal: true

require 'rails_helper'

# proyecto@crear_agente_conversando F3 — lo que la conversación decidió llega al redactor.
RSpec.describe ContactTrackings::Assistant::BriefFromChat do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:propuesta) do
    { 'objective' => 'Agendar demos', 'ai_context' => 'Kontrolya vende software',
      'variables' => 'SISTEMA = CONTPAQi | Aspel', 'datos_fijos' => "EMPRESA = Kontrolya\nQ1 (pregunta) = ¿Qué usas? → guarda en SISTEMA",
      'boceto' => "@ruta(demo #demo: quiero una demo): - -> @agendar_calendar\n@ruta_por_defecto: demo" }
  end
  let(:sesion) { TrackingAssistantSession.create!(account: account, user: user, proposal: propuesta) }
  let(:brief) { instance_double(TrackingAgentBrief, tracking_assistant_session: sesion) }
  let(:chat) { described_class.new(brief) }

  it 'da la Definición, las secciones y el boceto' do
    expect(chat.objective).to eq('Agendar demos')
    expect(chat.sections.keys).to eq(['VARIABLES', 'DATOS FIJOS'])
    expect(chat.message_block).to include("[DATOS FIJOS]\nEMPRESA = Kontrolya", '%Q1%', '@ruta(demo #demo: quiero una demo)')
  end

  it 'sin conversación no aporta nada' do
    vacio = described_class.new(instance_double(TrackingAgentBrief, tracking_assistant_session: nil))

    expect([vacio.objective, vacio.message_block, vacio.sections]).to eq([nil, nil, {}])
  end

  describe '#apply' do
    it 'reemplaza lo que reescribió el redactor por lo decidido, exacto' do
      lineas = ['[ROL]', 'Eres Leo', '', '[VARIABLES]', 'SISTEMA = contpaq | aspel | otro', '', '[DATOS FIJOS]',
                'EMPRESA = kontrolya', '@ruta(demo: demo): -']

      expect(chat.apply(lineas)).to eq(['[ROL]', 'Eres Leo', '', '[VARIABLES]', 'SISTEMA = CONTPAQi | Aspel', '',
                                        '[DATOS FIJOS]', 'EMPRESA = Kontrolya',
                                        'Q1 (pregunta) = ¿Qué usas? → guarda en SISTEMA', '', '@ruta(demo: demo): -'])
    end

    it 'si no las escribió, las agrega antes de la primera sección, en orden' do
      lineas = ['Hola', '[ROL]', 'Eres Leo']

      expect(chat.apply(lineas)).to eq(['Hola', '[VARIABLES]', 'SISTEMA = CONTPAQi | Aspel', '', '[DATOS FIJOS]',
                                        'EMPRESA = Kontrolya', 'Q1 (pregunta) = ¿Qué usas? → guarda en SISTEMA', '',
                                        '[ROL]', 'Eres Leo'])
    end
  end

  describe 'en BriefComposer y BriefCoverage' do
    let(:ficha) { { 'objetivo' => { 'texto' => 'otro objetivo' }, 'temas' => [{ 'nombre' => 'Demo' }] } }
    let(:brief) do
      TrackingAgentBrief.new(account: account, user: user, tracking_assistant_session: sesion, filename: 'i.md',
                             digest: { 'ficha' => ficha })
    end

    it 'el composer usa la Definición de la conversación y le pasa lo decidido al redactor' do
      resultado = ContactTrackings::Assistant::BriefComposer.new(brief).call

      expect(resultado[:proposal]).to eq(objective: 'Agendar demos', ai_context: 'Kontrolya vende software')
      expect(resultado[:message]).to include('SECCIONES YA DECIDIDAS', 'RUTAS YA PROBADAS')
    end

    it 'la cobertura deja las secciones exactas' do
      resultado = ContactTrackings::Assistant::BriefCoverage.new("[ROL]\nEres Leo", ficha: ficha, fixed: chat).call

      expect(resultado[:draft]).to start_with("[VARIABLES]\nSISTEMA = CONTPAQi | Aspel\n\n[DATOS FIJOS]\nEMPRESA = Kontrolya")
      expect(resultado[:fixed]).to eq(['VARIABLES', 'DATOS FIJOS'])
    end
  end
end
