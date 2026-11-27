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

  it 'con casos abiertos, «caso» dice cuál corrige; un número que no existe es servicio nuevo' do
    responde([{ ref: '1', etiqueta: 'Hiab 14 t', equipo: { tipo: 'hiab' }, paradas: [], caso: 1 },
              { ref: '2', etiqueta: 'Hiab 11 t', equipo: { tipo: 'hiab' }, paradas: [], caso: '7' }])

    servicios = described_class.new(account: account, text: 'de centro a paraíso',
                                    open_cases: ['1. Hiab 14 a 15 t (caso 01126)', '2. Hiab 12 t (caso 01127)']).call
    expect(servicios.map(&:case_ref)).to eq([1, nil])
  end

  it 'si la IA contesta con el folio en vez del número, también encuentra el caso' do
    responde([{ ref: '1', etiqueta: 'Hiab 11 t', equipo: { tipo: 'hiab' }, paradas: [], caso: '01127' }])

    servicios = described_class.new(account: account, text: 'el otro de 11 t',
                                    open_cases: ['1. Hiab 14 a 15 t (caso 01126)', '2. Hiab 12 t (caso 01127)']).call
    expect(servicios.map(&:case_ref)).to eq([2])
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

  describe '[GLOSARIO] del agente (27/11/2026)' do
    let(:inbox) { create(:inbox, account: account) }

    def tracking_con(prompt)
      template = create(:tracking_template, account: account, inbox: inbox, complementary_prompt: prompt)
      instance_double(ContactTracking, complementary_prompt: template.complementary_prompt, tracking_template: template, inbox: inbox)
    end

    it 'si el agente lo tiene, se le pasa al capturista; si no, el pedido queda igual' do
      responde([])
      prompt = "[ROL]\nx\n\n[GLOSARIO]\n- «TP» sola es tubería de perforación.\n\n[ESTILO]\ny"

      described_class.new(account: account, text: 'DESCARGA DE TP - KM14', tracking: tracking_con(prompt)).call
      expect(a_request(:post, chat_url).with { |req| req.body.include?('TP» sola es tubería') && req.body.exclude?('[ESTILO]') }).to have_been_made

      described_class.new(account: account, text: 'DESCARGA DE TP - KM14', tracking: tracking_con("[ROL]\nx")).call
      expect(a_request(:post, chat_url).with { |req| req.body.include?('Glosario') }).to have_been_made.once
    end
  end
end
