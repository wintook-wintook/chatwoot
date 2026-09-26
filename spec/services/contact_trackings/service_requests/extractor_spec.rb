require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Extractor do
  let(:account) { create(:account) }
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }

  before { create(:integrations_hook, :openai, account: account) }

  def responde(servicios)
    stub_request(:post, chat_url)
      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                 body: { choices: [{ message: { content: { servicios: servicios }.to_json } }] }.to_json)
  end

  def extraer(texto)
    described_class.new(account: account, text: texto).call
  end

  it 'arma cada servicio con lo que dijo el cliente, sin calcular fechas' do
    responde([{ ref: '1', etiqueta: 'Grúa 60 t', equipo: { tipo: 'grúa', capacidad_t: 60 },
                paradas: [{ tipo: 'origen', lugar: 'km 14+500' }, { tipo: 'destino', lugar: 'Blue Giant' }],
                fecha: '29 de mayo 2026', hora: '08:00 am', folios: ['NAV1'] },
              { ref: '2', etiqueta: 'Hiab', equipo: { tipo: 'hiab' }, paradas: [] }])

    servicios = extraer('1 grúa 60 tons y 01 camión con hiab, 29 de mayo 2026 08:00 am')
    expect(servicios.map(&:label)).to eq(['Grúa 60 t', 'Hiab'])
    expect(servicios.first.to_h.slice(:capacity_t, :date_text, :time_text, :folios))
      .to eq(capacity_t: 60.0, date_text: '29 de mayo 2026', time_text: '08:00 am', folios: ['NAV1'])
  end

  it '«entrega y recolección» de ida y vuelta se parte en dos servicios' do
    responde([{ ref: '1', etiqueta: 'Transporte', paradas: [{ tipo: 'origen', lugar: 'Carmen' },
                                                            { tipo: 'destino', lugar: 'Villahermosa' },
                                                            { tipo: 'destino', lugar: 'Carmen' }] }])

    servicios = extraer('1 servicio de transporte de entrega y recolección (Carmen – Villahermosa – Carmen)')
    expect(servicios.map(&:label)).to eq(['Transporte — entrega', 'Transporte — recolección'])
    expect(servicios.last.stops).to eq([{ 'tipo' => 'origen', 'lugar' => 'Villahermosa' },
                                        { 'tipo' => 'destino', 'lugar' => 'Carmen' }])
  end

  it 'un viaje redondo sin «entrega y recolección» sigue siendo uno' do
    responde([{ ref: '1', paradas: [{ lugar: 'Pozo' }, { lugar: 'Planta Linde' }, { lugar: 'Pozo' }] }])

    expect(extraer('De Pozo Madrefil 121 a Planta Linde y retorno al pozo').size).to eq(1)
  end

  it 'si la API falla devuelve nil: el motor sigue sin @solicitudes' do
    stub_request(:post, chat_url).to_return(status: 500)

    expect(extraer('1 grúa')).to be_nil
  end
end
