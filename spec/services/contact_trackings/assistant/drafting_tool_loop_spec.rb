require 'rails_helper'

# proyecto@crear_agente_conversando FR — preguntar con herramientas.
RSpec.describe ContactTrackings::Assistant::DraftingToolLoop do
  let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, last_error: nil) }
  let(:tools) { instance_double(ContactTrackings::Assistant::AssistantTools, route_errors: []) }
  let(:loop_) { described_class.new(chat, tools, model: 'gpt-5.4-mini', max_tokens: 100) }
  let(:pedido) { { 'id' => 'c1', 'type' => 'function', 'function' => { 'name' => 'ver_recursos', 'arguments' => '{}' } } }
  let(:final) { { 'role' => 'assistant', 'content' => { mensaje: 'Listo', boceto: '@ruta(a: x): -' }.to_json } }

  it 'corre lo que pide el modelo y sigue hasta que contesta' do
    allow(chat).to receive(:call_with_tools).and_return({ 'role' => 'assistant', 'content' => nil, 'tool_calls' => [pedido] }, final)
    allow(tools).to receive(:run).and_return('{"fuentes":[]}')
    expect(loop_.call([{ role: 'system', content: 'x' }])).to include('mensaje' => 'Listo')
    expect(loop_.log.pluck('herramienta')).to eq(['ver_recursos'])
  end

  it 'la misma consulta repetida no se vuelve a correr' do
    pide = { 'role' => 'assistant', 'content' => nil, 'tool_calls' => [pedido] }
    allow(chat).to receive(:call_with_tools).and_return(pide, pide, final)
    allow(tools).to receive(:run).and_return('{}')
    loop_.call([])
    expect(tools).to have_received(:run).once
  end

  it 'al llegar al tope le prohíbe más herramientas' do
    pide = { 'role' => 'assistant', 'content' => '{"mensaje":"con lo que vi"}', 'tool_calls' => [pedido] }
    allow(chat).to receive(:call_with_tools).and_return(pide)
    allow(tools).to receive(:run).and_return('{}')
    expect(loop_.call([])).to include('mensaje' => 'con lo que vi')
    expect(chat).to have_received(:call_with_tools).with(anything, hash_including(tool_choice: 'none')).once
  end

  it 'si la API rechaza el razonamiento con herramientas, repite con none' do
    allow(chat).to receive(:last_error).and_return('HTTP 400: … set reasoning_effort to none')
    allow(chat).to receive(:call_with_tools).with(anything, hash_including(reasoning_effort: nil)).and_return(nil)
    allow(chat).to receive(:call_with_tools).with(anything, hash_including(reasoning_effort: 'none')).and_return(final)
    expect(loop_.call([])).to include('mensaje' => 'Listo')
  end

  it 'recuerda las últimas rutas que se probaron' do
    probar = { 'id' => 'c2', 'type' => 'function',
               'function' => { 'name' => 'probar_ruta', 'arguments' => { frases: ['x'], rutas: '@ruta(a: x): -' }.to_json } }
    allow(chat).to receive(:call_with_tools).and_return({ 'role' => 'assistant', 'tool_calls' => [probar] }, final)
    allow(tools).to receive(:run).and_return('[]')
    loop_.call([])
    expect(loop_.last_routes).to eq('@ruta(a: x): -')
  end

  it 'si el boceto no lo ejecutaría el motor, le pide corregirlo' do
    malo = { 'role' => 'assistant', 'content' => { mensaje: 'Listo', boceto: '@ruta(a: x): Precios -> -' }.to_json }
    bueno = { 'role' => 'assistant', 'content' => { mensaje: 'Corregido', boceto: '@ruta(a: x): {{hoja:Precios}}' }.to_json }
    allow(chat).to receive(:call_with_tools).and_return(malo, bueno)
    allow(tools).to receive(:route_errors).with('@ruta(a: x): Precios -> -').and_return(['fuente que el motor no reconoce'])
    expect(loop_.call([])).to include('mensaje' => 'Corregido')
    # La lista de mensajes es la misma en las dos llamadas: se cuentan dos y que lleve el aviso.
    expect(chat).to have_received(:call_with_tools)
      .with(array_including(hash_including('content' => a_string_including('fuente que el motor no reconoce'))), anything)
      .twice
  end
end
