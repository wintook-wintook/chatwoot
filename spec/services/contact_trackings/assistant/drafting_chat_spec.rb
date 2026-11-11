# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — armar un agente desde cero conversando.
RSpec.describe ContactTrackings::Assistant::DraftingChat do
  let(:account) { create(:account) }
  let(:api) { ContactTrackings::Assistant::OpenaiChat::API_URL }
  let(:pedido) { [{ 'role' => 'user', 'content' => 'Quiero un agente para un consultorio de psicología que agende' }] }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  def modelo_contesta(json)
    stub_request(:post, api).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: json.to_json } }] }.to_json
    )
  end

  it 'devuelve la respuesta y las instrucciones actualizadas' do
    modelo_contesta('mensaje' => 'Tu cuenta tiene calendario conectado…',
                    'instrucciones' => "# Instrucciones iniciales: \n\n## Qué tiene que lograr\nAgendar citas.")

    resultado = described_class.new(account, messages: pedido).call

    expect(resultado).to include(reply: 'Tu cuenta tiene calendario conectado…', changed: true)
    expect(resultado[:instructions]).to include('Agendar citas.')
  end

  it 'si el modelo no cambió las instrucciones, quedan las que había' do
    modelo_contesta('mensaje' => '¿Cómo se llama el agente?', 'instrucciones' => nil)

    resultado = described_class.new(account, messages: pedido, instructions: "## Quién es\nLeo").call

    expect(resultado).to include(instructions: "## Quién es\nLeo", changed: false)
  end

  # La plantilla que se descarga en el modal es la que guía la conversación, y el modelo
  # ve los recursos de la cuenta en palabras, no en la sintaxis del motor.
  it 'conversa con gpt-5.4-mini, la plantilla y los recursos de la cuenta' do
    modelo_contesta('mensaje' => 'ok', 'instrucciones' => nil)
    CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')

    described_class.new(account, messages: pedido).call

    expect(a_request(:post, api).with do |req|
      cuerpo = JSON.parse(req.body)
      sistema = cuerpo['messages'].first['content']
      cuerpo['model'] == 'gpt-5.4-mini' && cuerpo.key?('max_completion_tokens') && !cuerpo.key?('temperature') &&
        sistema.include?('## Lo que la gente viene a pedir') && sistema.include?('Abrir casos para que los atienda una persona')
    end).to have_been_made
  end

  # proyecto@crear_agente_conversando F3
  it 'lleva lo que ya hay en las pestañas y devuelve solo lo que cambió' do
    modelo_contesta('mensaje' => 'Anoté la pregunta 1', 'instrucciones' => nil, 'definicion' => nil,
                    'datos_fijos' => [{ 'nombre' => 'Q1', 'tipo' => 'pregunta', 'contenido' => '¿Qué usas?', 'guarda_en' => 'SISTEMA' }])

    resultado = described_class.new(account, messages: pedido,
                                             so_far: { fields: { 'variables' => 'SISTEMA = A | B', 'objective' => 'Demos' } }).call

    expect(resultado[:fields]).to eq('datos_fijos' => 'Q1 (pregunta) = ¿Qué usas? → guarda en SISTEMA')
    expect(a_request(:post, api).with do |req|
      mensajes = JSON.parse(req.body)['messages']
      mensajes.first['content'].include?('"datos_fijos"') &&
        mensajes.any? { |m| m['content'].include?("Objetivo: Demos\n\nVariables:\nSISTEMA = A | B") }
    end).to have_been_made
  end

  it 'sin respuesta del modelo, avisa que no pudo' do
    stub_request(:post, api).to_return(status: 500, body: 'x')

    expect(described_class.new(account, messages: pedido).call).to eq(error: :unavailable)
  end
end
