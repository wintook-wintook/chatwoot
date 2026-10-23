# frozen_string_literal: true

require 'rails_helper'

# proyecto@hoja_buscar — las columnas que regresa una {{hoja_buscar:}} no le llegan al modelo.
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ana Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact,
                     content: '¿Qué horarios tiene la TP-64 para mañana?')
  end
  let(:source) do
    create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Servicio Gruas',
                              config: { 'sheet_mode' => 'faq' })
  end
  let(:fila) do
    KnowledgeItem.new(title: 'Servicio Gruas — fila 1',
                      content: "remolque: TP-64\npeso_max_t: 60\nCalendar_ID: https://calendar.google.com/calendar/embed?src=c64")
  end
  let(:chat_url) { 'https://api.openai.com/v1/chat/completions' }

  before do
    create(:integrations_hook, :openai, account: account)
    stub_request(:post, chat_url)
      .to_return(status: 200, body: { choices: [{ message: { content: 'La TP-64 carga hasta 60 t.' } }] }.to_json)
  end

  def servicio_con(prompt)
    tracking = create(:contact_tracking, account: account, contact: contact, inbox: inbox, complementary_prompt: prompt)
    described_class.new(message, tracking: tracking, branch: nil).tap do |service|
      allow(service).to receive(:search_items).and_return([fila])
    end
  end

  def contexto_enviado(prompt)
    servicio_con(prompt).send(:perform_sheet_faq, message.content, source)

    body = nil
    expect(a_request(:post, chat_url).with { |r| body = JSON.parse(r.body) }).to have_been_made
    body['messages'].pluck('content').join("\n")
  end

  it 'con {{hoja_buscar:}} de agenda sobre esa hoja, el modelo no recibe la columna que regresa' do
    enviado = contexto_enviado("@ruta(disponibilidad: horarios de un remolque): - -> \
{{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar\nAgente.")

    expect(enviado).to include('peso_max_t: 60')
    expect(enviado).not_to include('calendar.google.com')
  end

  it 'sin {{hoja_buscar:}} la fila llega completa, como siempre' do
    expect(contexto_enviado('Agente de grúas.')).to include('Calendar_ID: https://calendar.google.com')
  end

  # Pieza 2: {{hoja_buscar:}} como FUENTE de la ruta — el modelo recibe las filas exactas.
  describe 'como fuente de la ruta' do
    let(:unidades) do
      create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Unidades', config: { 'sheet_mode' => 'faq' })
    end
    let(:lookup) { '{{hoja_buscar: Unidades | economico=? | operador, placas}}' }

    before do
      account.enable_features!('google_calendar')
      GoogleSheetRow.create!(account: account, knowledge_source: unidades, row_index: 0,
                             data: { 'economico' => 'TP-60', 'operador' => 'Engar Bravo', 'placas' => '82AU1W', 'telefono' => '555' })
    end

    def responder(texto)
      message.update!(content: texto)
      tracking = create(:contact_tracking, account: account, contact: contact, inbox: inbox,
                                           complementary_prompt: "@ruta(asignacion: datos de unidad): #{lookup}")
      described_class.new(message, tracking: tracking, branch: ContactTrackings::RouteMap.parse(tracking.complementary_prompt).routes.first).perform
    end

    def enviado
      body = nil
      expect(a_request(:post, chat_url).with { |r| body = JSON.parse(r.body) }).to have_been_made
      body['messages'].pluck('content').join("\n")
    end

    it 'detecta la directiva como fuente' do
      expect(KnowledgeBase::Directives.detect(lookup)).to include(mode: :sheet_lookup)
      expect(KnowledgeBase::Directives.available?(lookup, account: account, inbox_id: inbox.id)).to be(true)
    end

    it 'le da al modelo la fila exacta, solo con las columnas pedidas' do
      expect(responder('Favor de confirmar datos de la unidad TP-60')).to be(true)
      expect(enviado).to include('economico: TP-60 · operador: Engar Bravo · placas: 82AU1W')
      expect(enviado).not_to include('telefono')
    end

    it 'si no nombró la unidad, le pide que pregunte cuál' do
      responder('Favor de confirmar datos de la unidad')
      expect(enviado).to include('falta saber «economico»')
    end

    describe 'con un valor fijo que no está en la hoja' do
      let(:lookup) { '{{hoja_buscar: Unidades | economico=TP-999 | operador}}' }

      it 'lo dice sin inventar' do
        responder('Datos de la unidad')
        expect(enviado).to include('no hay ninguna fila con: economico = TP-999')
      end
    end
  end
end
