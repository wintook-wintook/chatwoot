# frozen_string_literal: true

require 'rails_helper'

# feat/plantillas_variables_resolver F9.3 — un seguimiento (o campaña) con una plantilla con
# nombres saca los datos del contacto; sin el dato no manda nada y queda el motivo, sin pausar
# la campaña. Meta se simula con webmock.
RSpec.describe ContactTrackingJob do
  let(:plantillas) do
    [{ 'name' => 'saludo', 'status' => 'approved', 'language' => 'es_MX',
       'components' => [{ 'type' => 'BODY', 'text' => 'Hola {{primer_nombre}}, tu plan es {{plan}}. Caso {{conversacion}}.' }] },
     { 'name' => 'con_titulo', 'status' => 'approved', 'language' => 'es_MX', 'parameter_format' => 'NAMED',
       'components' => [{ 'type' => 'HEADER', 'format' => 'TEXT', 'text' => 'Para {{primer_nombre}}' },
                        { 'type' => 'BODY', 'text' => 'Te atiende {{agente}}.' }] },
     { 'name' => 'numerada', 'status' => 'approved', 'language' => 'es_MX',
       'components' => [{ 'type' => 'BODY', 'text' => 'Hola {{1}}, gracias.' }] }]
  end
  let!(:account) { create(:account) }
  let!(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                              message_templates: plantillas)
  end
  let(:inbox) { channel.inbox }
  let!(:contact) do
    create(:contact, account: account, name: 'Juan Pérez', phone_number: '+5215512345678', custom_attributes: { plan: 'Plus' })
  end
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:nombre_plantilla) { 'saludo' }
  let!(:envio) do
    stub_request(:post, %r{graph\.facebook\.com/.*/messages})
      .to_return(status: 200, body: { messages: [{ id: 'wamid.1' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  before do
    stub_request(:get, %r{graph\.facebook\.com/v21\.0/.*/message_templates})
      .to_return(status: 200, body: { data: [{ name: 'saludo', language: 'es_MX' }] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  # Sin mensaje del cliente la ventana de 24 h está cerrada y sale la plantilla.
  def tracking_for(conversation_id: conversation.id)
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation_id: conversation_id,
                              status: 'scheduled', scheduled_for: 1.hour.from_now, whatsapp_templates: [nombre_plantilla] * 3)
      .tap { |t| t.update_column(:scheduled_for, 1.minute.ago) } # rubocop:disable Rails/SkipsModelValidations
  end

  def sent_components
    componentes = nil
    expect(WebMock).to(have_requested(:post, %r{graph\.facebook\.com/.*/messages}).with do |req|
      componentes = JSON.parse(req.body).dig('template', 'components')
    end)
    componentes
  end

  it 'manda cada variable con su nombre y el mensaje guardado lleva los datos' do
    described_class.perform_now(tracking_for.id)

    expect(sent_components).to eq([{ 'type' => 'body', 'parameters' => [
                                    { 'type' => 'text', 'parameter_name' => 'primer_nombre', 'text' => 'Juan' },
                                    { 'type' => 'text', 'parameter_name' => 'plan', 'text' => 'Plus' },
                                    { 'type' => 'text', 'parameter_name' => 'conversacion', 'text' => conversation.display_id.to_s }
                                  ] }])
    expect(conversation.messages.outgoing.last.content).to eq("Hola Juan, tu plan es Plus. Caso #{conversation.display_id}.")
  end

  it 'en el primer envío usa la conversación recién creada' do
    described_class.perform_now(tracking_for(conversation_id: nil).id)

    numero = sent_components.first['parameters'].find { |p| p['parameter_name'] == 'conversacion' }['text']
    expect(numero).to eq(contact.conversations.where(inbox: inbox).last.display_id.to_s)
  end

  context 'with variables en el encabezado de texto' do
    let(:nombre_plantilla) { 'con_titulo' }

    it 'las manda en el encabezado; sin nadie asignado, el agente es el Agente IA' do
      plantilla_ia = create(:tracking_template, account: account, customer_display_name: 'Sofía')
      tracking = tracking_for
      tracking.update!(tracking_template: plantilla_ia)

      described_class.perform_now(tracking.id)

      expect(sent_components).to eq([
                                      { 'type' => 'header', 'parameters' => [{ 'type' => 'text', 'parameter_name' => 'primer_nombre',
                                                                               'text' => 'Juan' }] },
                                      { 'type' => 'body', 'parameters' => [{ 'type' => 'text', 'parameter_name' => 'agente',
                                                                             'text' => 'Sofía' }] }
                                    ])
    end

    it 'con alguien asignado, el agente es esa persona' do
      asignado = create(:user, account: account, name: 'Ana Ruiz', display_name: 'Anita')
      conversation.update!(assignee: asignado)

      described_class.perform_now(tracking_for.id)

      expect(sent_components.last['parameters'].first['text']).to eq('Anita')
    end
  end

  describe 'sin el dato' do
    before { contact.update!(custom_attributes: {}) }

    it 'no manda nada, queda el motivo y no pausa la campaña' do
      tracking = tracking_for

      described_class.perform_now(tracking.id)

      expect(envio).not_to have_been_made
      entrega = tracking.tracking_deliveries.last
      expect(entrega).to have_attributes(status: 'failed', error_code: 'template_data_missing', error_kind: 'permanent')
      expect(entrega.error_title).to include('{{plan}}')
    end
  end

  context 'with una plantilla numerada' do
    let(:nombre_plantilla) { 'numerada' }

    it 'sigue igual que antes' do
      described_class.perform_now(tracking_for.id)

      expect(sent_components).to eq([{ 'type' => 'body', 'parameters' => [{ 'type' => 'text', 'text' => 'Juan Pérez' }] }])
    end
  end
end
