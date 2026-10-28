require 'rails_helper'

# proyecto@diagrama_agente_ia F0 — docs/diagrama_agente_ia_plan.md §3
RSpec.describe ContactTrackings::EngineTrace do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:incoming) { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming) }
  let(:route) { ContactTrackings::RouteMap::Route.new(name: 'cotizar', tag: 'cotizar', directive: '{{doc:Lista}}') }

  def reply(text = 'Claro')
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: text)
  end

  it 'escribe en cada respuesta del turno lo que anotaron las etapas' do
    item = Struct.new(:title, :neighbor_distance).new('Lista de precios', 0.18)
    first = second = nil
    described_class.run(incoming) do
      described_class.route(route, :clasificada)
      described_class.source({ mode: :google_doc, source_name: 'Lista' })
      described_class.fragments([item])
      described_class.usage('gpt-4o', { 'usage' => { 'total_tokens' => 120 } })
      described_class.usage('gpt-4o-mini', '{"usage":{"total_tokens":30}}')
      first = reply
      second = reply('Otra')
      described_class.answered(:kbase)
    end

    traza = first.reload.content_attributes['traza']
    expect(traza).to include(
      'v' => 1, 'mensaje_id' => incoming.id, 'camino' => 'kbase', 'respuesta' => '1/2',
      'ruta' => { 'nombre' => 'cotizar', 'etiqueta' => '#cotizar', 'como' => 'clasificada' },
      'fuente' => { 'modo' => 'google_doc', 'nombre' => 'Lista' },
      'fragmentos' => [{ 'titulo' => 'Lista de precios', 'similitud' => 0.82 }],
      'uso' => { 'llamadas' => 2, 'tokens' => 150, 'modelos' => %w[gpt-4o gpt-4o-mini] }
    )
    expect(traza['ms']).to be_a(Integer)
    expect(second.reload.content_attributes.dig('traza', 'respuesta')).to eq('2/2')
  end

  it 'no guarda el texto del cliente ni el de los fragmentos' do
    described_class.run(incoming) do
      described_class.fragments([Struct.new(:title, :neighbor_distance, :content).new('T', 0.1, 'secreto')])
      reply
    end

    expect(conversation.messages.outgoing.last.content_attributes['traza'].to_json).not_to include('secreto', incoming.content.to_s)
  end

  it 'no toca mensajes de otra conversación ni los entrantes' do
    other_conversation = create(:conversation, account: account, inbox: inbox)
    described_class.run(incoming) do
      create(:message, account: account, inbox: inbox, conversation: other_conversation, message_type: :outgoing)
    end

    expect(other_conversation.messages.map { |m| m.content_attributes['traza'] }).to all(be_nil)
    expect(incoming.reload.content_attributes['traza']).to be_nil
  end

  it 'fuera de un turno cada anotación es un no-op' do
    expect(described_class.active?).to be(false)
    expect { described_class.route(route, :unica) }.not_to raise_error
    expect(reply.reload.content_attributes['traza']).to be_nil
  end

  it 'marca la ruta ausente y la etiqueta repuesta' do
    described_class.run(incoming) do
      described_class.route(nil, :por_defecto)
      described_class.tag_restored('#cotizar')
      reply
    end

    expect(conversation.messages.outgoing.last.content_attributes['traza'])
      .to include('ruta' => { 'como' => 'sin_ruta' }, 'etiqueta_repuesta' => '#cotizar')
  end

  it 'limpia el estado aunque el turno falle' do
    expect { described_class.run(incoming) { raise 'boom' } }.to raise_error('boom')
    expect(described_class.active?).to be(false)
  end

  it 'la traza no sale en el webhook' do
    message = reply
    message.update_columns(content_attributes: { 'traza' => { 'v' => 1 }, 'otro' => 1 }) # rubocop:disable Rails/SkipsModelValidations

    expect(message.reload.webhook_data[:content_attributes].keys).to eq(['otro'])
  end

  describe 'en el job, de punta a punta' do
    let(:template) { create(:tracking_template, account: account) }
    let!(:tracking) do
      create(:contact_tracking, account: account, inbox: inbox, contact: contact, conversation: conversation,
                                tracking_template: template, status: 'active',
                                complementary_prompt: "[ROL] Asistente.\n[MENSAJE DE BIENVENIDA]\nHola, soy el asistente.")
    end

    it 'la bienvenida queda con su camino' do
      incoming_message = create(:message, account: account, inbox: inbox, conversation: conversation,
                                          sender: contact, message_type: :incoming, content: 'hola')
      ContactTrackingResponseAnalyzerJob.new.perform(incoming_message.id)

      bot = conversation.messages.outgoing.where('id > ?', incoming_message.id).last
      expect(bot.content).to include('Hola, soy el asistente.')
      expect(bot.content_attributes['traza']).to include('camino' => 'bienvenida', 'mensaje_id' => incoming_message.id)
      expect(tracking).to be_persisted
    end
  end
end
