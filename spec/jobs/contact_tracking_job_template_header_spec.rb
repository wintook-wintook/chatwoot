# frozen_string_literal: true

require 'rails_helper'

# feat/plantillas_whatsapp_mejoras F5 — un seguimiento con plantilla de documento manda el
# archivo guardado; sin archivo no se envía y se pausa con el motivo. Meta se simula con webmock.
RSpec.describe ContactTrackingJob do
  let!(:account) { create(:account) }
  let!(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                              message_templates: [{ 'name' => 'factura', 'status' => 'approved', 'language' => 'es_MX',
                                                    'components' => [{ 'type' => 'HEADER', 'format' => 'DOCUMENT' },
                                                                     { 'type' => 'BODY', 'text' => 'Tu factura está lista' }] }])
  end
  let(:inbox) { channel.inbox }
  let!(:contact) { create(:contact, account: account, phone_number: '+5215512345678') }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let!(:tracking) do
    # Sin mensaje del cliente: la ventana de 24 h está cerrada y sale la plantilla.
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation_id: conversation.id,
                              status: 'scheduled', scheduled_for: 1.hour.from_now, whatsapp_templates: %w[factura factura factura])
      .tap { |t| t.update_column(:scheduled_for, 1.minute.ago) } # rubocop:disable Rails/SkipsModelValidations
  end
  let!(:envio) do
    stub_request(:post, %r{graph\.facebook\.com/.*/messages})
      .to_return(status: 200, body: { messages: [{ id: 'wamid.doc' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  before do
    stub_request(:get, %r{graph\.facebook\.com/v21\.0/.*/message_templates})
      .to_return(status: 200, body: { data: [{ name: 'factura', language: 'es_MX' }] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  it 'manda el documento guardado como encabezado y la burbuja lo guarda' do
    create(:whatsapp_template, channel_whatsapp: channel, account: account, name: 'factura', language: 'es_MX',
                               header_type: 'document', header_media_url: 'https://cdn.mx/factura.pdf')

    described_class.perform_now(tracking.id)

    expect(envio.with do |req|
      JSON.parse(req.body).dig('template', 'components').first ==
        { 'type' => 'header', 'parameters' => [{ 'type' => 'document',
                                                 'document' => { 'link' => 'https://cdn.mx/factura.pdf',
                                                                 'filename' => 'factura.pdf' } }] }
    end).to have_been_made
    mensaje = conversation.messages.outgoing.last
    expect(mensaje.additional_attributes.dig('template_params', 'processed_params', 'header'))
      .to include('media_url' => 'https://cdn.mx/factura.pdf', 'media_type' => 'document')
    expect(tracking.tracking_deliveries.last).to have_attributes(status: 'sent', source_id: 'wamid.doc')
    # Guardar template_params no lo vuelve a enviar: el mensaje ya lleva source_id.
    Whatsapp::SendOnWhatsappService.new(message: mensaje).perform
    expect(envio).to have_been_made.once
  end

  it 'sin archivo guardado no manda nada y se pausa con el motivo' do
    described_class.perform_now(tracking.id)

    expect(envio).not_to have_been_made
    expect(tracking.tracking_deliveries.last).to have_attributes(status: 'failed', error_code: 'template_media_missing',
                                                                 error_kind: 'config')
    expect(tracking.reload.status).not_to eq('completed')
  end

  # La plantilla se borró (aquí o en Meta) o ya no está aprobada: no se manda nada (ni texto
  # libre en su lugar) y queda el motivo como error de configuración.
  it 'si la plantilla ya no existe en la bandeja no manda nada y queda el motivo' do
    tracking.update!(whatsapp_templates: %w[borrada borrada borrada])

    described_class.perform_now(tracking.id)

    expect(envio).not_to have_been_made
    expect(tracking.tracking_deliveries.last).to have_attributes(status: 'failed', error_code: '132001', error_kind: 'config')
    expect(tracking.tracking_deliveries.last.error_title).to include('ya no existe')
  end

  it 'si la plantilla no está aprobada no se manda' do
    channel.update!(message_templates: channel.message_templates.map { |t| t.merge('status' => 'PAUSED') })

    described_class.perform_now(tracking.id)

    expect(envio).not_to have_been_made
    expect(tracking.tracking_deliveries.last).to have_attributes(error_code: '132015', error_kind: 'config')
  end
end
