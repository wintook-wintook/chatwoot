require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Interpreter do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }
  let(:inicio) { Time.zone.parse('2026-10-21 18:00 UTC') }
  let(:caso) do
    ofertas = %w[1A 1B].each_with_index.map do |codigo, i|
      { 'code' => codigo, 'slot' => (inicio + (i * 2).hours).iso8601, 'end_time' => (inicio + ((i * 2) + 1).hours).iso8601,
        'calendar_name' => 'TP-46' }
    end
    CaseTicket.create!(account: account, conversation: conversation, contact: conversation.contact, title: 'Rabón',
                       metadata: { 'servicio' => { 'label' => 'Rabón', 'time' => '12:00' }, 'oferta' => ofertas })
  end

  before { create(:integrations_hook, :openai, account: account) }

  def responde(json)
    stub_request(:post, chat_url)
      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                 body: { choices: [{ message: { content: json.to_json } }] }.to_json)
  end

  def leer(texto)
    described_class.new(account: account, text: texto, cases: [[1, caso]], timezone: 'America/Mexico_City').call
  end

  it '«Adelante con el horario» es una afirmación general' do
    responde(accion: 'elegir', general: true, codigos: [])

    expect(leer('Adelante con el horario').to_h).to eq(action: :elegir, general: true, codes: [])
  end

  it 'manda las opciones con hora, unidad y la hora que pidió' do
    responde(accion: 'elegir', general: false, codigos: ['1b'])

    expect(leer('la de las 14').codes).to eq(['1B'])
    expect(a_request(:post, chat_url).with { |req| req.body.include?('1B: mié 21 oct 14:00–15:00 (unidad TP-46)') }).to have_been_made
    expect(a_request(:post, chat_url).with { |req| req.body.include?('(pidió las 12:00)') }).to have_been_made
  end

  it 'descarta códigos que no se ofrecieron; «elegir» sin ninguno válido pasa a pregunta' do
    responde(accion: 'elegir', general: false, codigos: ['3C'])

    expect(leer('la C').to_h).to eq(action: :ambigua, general: false, codes: [])
  end

  it 'rechazo y otra pasan tal cual' do
    responde(accion: 'rechazo', general: false, codigos: [])
    expect(leer('ninguna me sirve').action).to eq(:rechazo)

    responde(accion: 'otra', general: false, codigos: [])
    expect(leer('¿cuánto cuesta?').action).to eq(:otra)
  end

  it 'sin clave, con error de la API o con una acción desconocida devuelve nil' do
    responde(accion: 'quien sabe')
    expect(leer('sí')).to be_nil

    stub_request(:post, chat_url).to_return(status: 500)
    expect(leer('sí')).to be_nil

    account.hooks.destroy_all
    expect(leer('sí')).to be_nil
  end
end
