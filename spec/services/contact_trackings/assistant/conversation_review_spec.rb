# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — revisar una conversación real
RSpec.describe ContactTrackings::Assistant::ConversationReview do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  # Una sola ruta: el clasificador la devuelve sin llamar al modelo.
  let(:prompt) { "@ruta(agendar_cita #agendar: quiere una cita): - -> @agendar_calendar\n\n[ESTILO]\nBreve." }
  let(:veredicto) do
    { resumen: 'Prometió algo que no hizo.',
      turnos: [{ n: 2, veredicto: 'mal', que_paso: 'Prometió confirmar y no confirmó.', que_se_esperaba: 'Ofrecer horarios.',
                 causa: 'entrenamiento', arreglo: 'Prohibir prometer.', ya_corregido: false },
               { n: 4, veredicto: 'bien' }, { n: 99, veredicto: 'mal', causa: 'motor' }],
      cambios_entrenamiento: ['Prohibir prometer acciones que no hace.'] }
  end

  before do
    account.hooks.create!(app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: veredicto.to_json } }] }.to_json
    )
    create(:contact_tracking, account: account, inbox: inbox, conversation: conversation, complementary_prompt: prompt)
    [['incoming', 'quiero una cita', {}],
     ['outgoing', 'Te confirmo en un momento #humano', { sentiment_auto_reply: true }],
     ['incoming', 'cuándo es mi cita', {}],
     ['outgoing', 'Ya tenés una cita el jueves', { sentiment_auto_reply: true }]].each do |tipo, texto, attrs|
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: tipo,
                       content: texto, content_attributes: attrs)
    end
  end

  def revisar(**opts)
    described_class.new(account, display_id: conversation.display_id, **opts).call
  end

  it 'junta el juicio del modelo con lo comprobado sin IA, por respuesta' do
    r = revisar

    expect(r[:findings].map { |f| [f[:n], f[:verdict], f[:cause]] }).to eq([[2, 'mal', 'entrenamiento'], [4, 'mal', 'motor']])
    expect(r[:findings].first[:signals].pluck(:code)).to eq(['wrong_tag'])
    expect(r[:findings].last[:signals].pluck(:code)).to eq(['voseo'])
  end

  it 'una respuesta con señales no cuenta como bien aunque el modelo la diera por buena' do
    expect(revisar[:ok]).to eq([])
  end

  it 'ignora números que no son respuestas del bot' do
    expect(revisar[:findings].pluck(:n)).not_to include(99)
  end

  it 'avisa que el agente agenda sin calendario' do
    expect(revisar[:facts]).to include({ code: 'no_calendar' })
  end

  it 'le pasa al modelo lo que dijo la persona y lo que hace el motor hoy' do
    revisar(note: 'la 2 está mal')

    expect(WebMock).to(have_requested(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).with do |req|
      texto = JSON.parse(req.body)['messages'].first['content']
      texto.include?('la 2 está mal') && texto.include?('motor hoy: ruta: agendar_cita') && texto.include?('etiqueta de su ruta')
    end)
  end

  it 'no encuentra una conversación de otra cuenta' do
    expect(described_class.new(account, display_id: create(:conversation).display_id + 10_000).call).to eq({ error: 'not_found' })
  end

  it 'sin API key no llama a nadie' do
    account.hooks.destroy_all

    expect(revisar).to eq({ error: 'no_api_key' })
  end
end
