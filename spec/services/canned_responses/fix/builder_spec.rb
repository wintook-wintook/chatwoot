# frozen_string_literal: true

require 'rails_helper'

# proyecto@arreglar_predefinidas — armar la propuesta (IA y vectores simulados).
RSpec.describe CannedResponses::Fix::Builder do
  let(:account) { create(:account) }
  let(:proposer) { instance_double(CannedResponses::Fix::Proposer, last_error: nil) }
  let(:embedder) { instance_double(CannedResponses::Fix::Embedder) }
  let(:ficha) do
    "PRODUCTO X\n\nPRECIOS\nCuesta $1,500 al mes.\n\nSOPORTE\nLlama al 55 1234 5678 de 9:00 a 18:00.\n\n#{'Detalle largo. ' * 140}"
  end
  let(:original) { create(:canned_response, account: account, short_code: 'Producto X', content: ficha) }

  before do
    create(:integrations_hook, :openai, account: account)
    allow(CannedResponses::Fix::Proposer).to receive(:new).and_return(proposer)
    allow(CannedResponses::Fix::Embedder).to receive(:new).and_return(embedder)
    allow(embedder).to receive(:call) { |textos| textos.map { |t| [t.size.to_f, 1.0] + Array.new(1534, 0.0) } }
  end

  def parte(nombre, contenido) = { 'short_code' => nombre, 'content' => contenido }

  def propuesta(accion, partes)
    { 'action' => accion, 'shape' => 'sections', 'subject' => 'Producto X', 'reason' => 'r', 'parts' => partes,
      'questions' => [{ 'text' => '¿Cuánto cuesta Producto X?', 'part' => 0 }] }
  end

  it 'si con limpiar basta, no llama a la IA' do
    sucia = create(:canned_response, account: account, short_code: 'Redes',
                                     content: "Síguenos en https://x.mx\n\n![logo](data:image/png;base64,#{'A' * 3000})")
    allow(proposer).to receive(:call)

    salida = described_class.new(account).call(sucia)

    expect(proposer).not_to have_received(:call)
    expect(salida[:proposal]).to include('action' => 'clean')
    expect(salida[:proposal]['parts'].sole['content']).to eq('Síguenos en https://x.mx')
    expect(salida[:checks]['blocking']).to eq([])
  end

  it 'le pasa a la IA los datos obligatorios y los prefijos de grupo de los agentes' do
    create(:tracking_template, account: account, complementary_prompt: '@buscar_predefinidas(Producto)')
    partes = [parte('Producto X — Precios', "Producto X\nCuesta $1,500 al mes."),
              parte('Producto X — Soporte', "Producto X\nLlama al 55 1234 5678 de 9:00 a 18:00. #{'Detalle largo. ' * 100}")]
    allow(proposer).to receive(:call).and_return(propuesta('split', partes))

    salida = described_class.new(account).call(original)

    expect(proposer).to have_received(:call).with(hash_including(prefixes: ['Producto'],
                                                                 hard_data: include(hash_including('text' => '$1,500'))))
    expect(salida[:checks]['data']).to include('ok' => true)
    expect(salida[:checks]['search']).to include('total' => 1)
  end

  it 'si faltan datos, da una segunda vuelta con los problemas y se queda con la mejor' do
    mala = propuesta('split', [parte('Producto X — Todo', "Producto X\nCuesta poco. #{'Detalle largo. ' * 140}")])
    buena = propuesta('split', [parte('Producto X — Precios', "Producto X\nCuesta $1,500 al mes."),
                                parte('Producto X — Soporte', "Producto X\nLlama al 55 1234 5678 de 9:00 a 18:00. #{'Detalle largo. ' * 100}")])
    allow(proposer).to receive_messages(call: mala, repair: buena)

    salida = described_class.new(account).call(original)

    expect(proposer).to have_received(:repair).with(hash_including(problems: include(a_string_including('$1,500'))))
    expect(salida[:proposal]).to include('repaired' => true)
    expect(salida[:checks]['blocking']).to eq([])
  end

  it 'si una parte sigue pasando el tope, la parte por bloques sin reescribirla' do
    grande = propuesta('split', [parte('Producto X — Todo', ficha)])
    allow(proposer).to receive_messages(call: grande, repair: grande)

    salida = described_class.new(account).call(original)

    expect(salida[:proposal]['fallback']).to eq('rebalanced')
    expect(salida[:checks]['size']['ok']).to be(true)
    # Ni una palabra del original se pierde (las partes pueden llevar además el sujeto).
    quedan = salida[:proposal]['parts'].flat_map { |p| p['content'].split }.tally
    expect(ficha.split.tally.all? { |w, n| quedan[w].to_i >= n }).to be(true)
  end

  it 'si condensar pierde contenido, divide el original por bloques' do
    corta = propuesta('condense', [parte('cualquiera', 'Producto X cuesta $1,500. Tel 55 1234 5678 de 9:00 a 18:00.')])
    allow(proposer).to receive_messages(call: corta, repair: corta)

    salida = described_class.new(account).call(original)

    expect(salida[:proposal]).to include('action' => 'split', 'fallback' => 'mechanical')
    expect(salida[:checks]['coverage']['dropped_count']).to eq(0)
  end

  it 'las instrucciones en una sola parte conservan el nombre de la original' do
    instrucciones = create(:canned_response, account: account, short_code: 'BOT', content: "Eres el asistente. #{'Debes ser amable. ' * 130}")
    allow(proposer).to receive(:call).and_return(propuesta('mark_prompt', [parte('BOT — Reglas', 'Eres el asistente. Debes ser amable.')]))
    allow(proposer).to receive(:repair).and_return(nil)

    salida = described_class.new(account).call(instrucciones)

    expect(salida[:proposal]['parts'].sole['short_code']).to eq('BOT')
  end

  it 'si la IA no contesta, dice por qué' do
    allow(proposer).to receive_messages(call: nil, last_error: 'HTTP 429: insufficient_quota')

    builder = described_class.new(account)
    expect(builder.call(original)).to be_nil
    expect(builder.error_code).to eq('no_credits')
  end

  it 'cada parte nombra al sujeto al principio aunque la IA no lo haga' do
    partes = [parte('Producto X — Precios', "Producto X\nCuesta $1,500 al mes."),
              parte('Producto X — Soporte', "SOPORTE\nLlama al 55 1234 5678 de 9:00 a 18:00. #{'Detalle largo. ' * 100}")]
    allow(proposer).to receive(:call).and_return(propuesta('split', partes))

    salida = described_class.new(account).call(original)

    expect(salida[:proposal]['parts'].map { |p| p['content'].lines.first.strip }).to eq(['Producto X', 'Producto X'])
  end
end

