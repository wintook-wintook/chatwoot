# frozen_string_literal: true

require 'rails_helper'

# feat/plantillas_whatsapp_mejoras F5 — el archivo del encabezado en seguimientos y campañas
RSpec.describe ContactTrackings::TemplateHeader do
  let(:plantillas) do
    [
      { 'name' => 'factura', 'status' => 'approved', 'language' => 'es_MX',
        'components' => [{ 'type' => 'HEADER', 'format' => 'DOCUMENT' }, { 'type' => 'BODY', 'text' => 'Tu factura {{1}}' }] },
      { 'name' => 'saludo', 'status' => 'approved', 'language' => 'es_MX',
        'components' => [{ 'type' => 'HEADER', 'format' => 'TEXT', 'text' => 'Hola' }, { 'type' => 'BODY', 'text' => 'Qué tal' }] }
    ]
  end
  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                              message_templates: plantillas)
  end

  def guardar(url, language: 'es_MX')
    create(:whatsapp_template, channel_whatsapp: channel, account: channel.account, name: 'factura', language: language,
                               header_type: 'document', header_media_url: url)
  end

  it 'una plantilla sin archivo no cambia nada' do
    expect(described_class.for(channel, 'saludo', 'es_MX')).to be_nil
    expect(described_class.for(channel, 'no_existe', 'es_MX')).to be_nil
  end

  it 'con el archivo guardado arma el encabezado y conserva el cuerpo' do
    guardar('https://cdn.mx/docs/Factura%20A1.pdf')

    header = described_class.for(channel, 'factura', 'es_MX')

    expect(header.error).to be_nil
    expect(header.components([{ type: 'text', text: 'A1' }])).to eq([
                                                                      { type: 'header', parameters: [
                                                                        { type: 'document',
                                                                          document: { link: 'https://cdn.mx/docs/Factura%20A1.pdf',
                                                                                      filename: 'Factura%20A1.pdf' } }
                                                                      ] },
                                                                      { type: 'body', parameters: [{ type: 'text', text: 'A1' }] }
                                                                    ])
    expect(header.processed_header).to include('media_type' => 'document', 'media_url' => 'https://cdn.mx/docs/Factura%20A1.pdf')
  end

  it 'con el archivo subido en la pantalla (F6) usa ese y su nombre original' do
    fila = guardar(nil)
    fila.header_sample.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'Factura A1.pdf',
                              content_type: 'application/pdf')

    media = described_class.for(channel, 'factura', 'es_MX').media

    expect(media[:url]).to include('/rails/active_storage/')
    expect(media[:name]).to eq('Factura A1.pdf')
  end

  it 'para la burbuja guarda una liga que no caduca, distinta de la de Meta' do
    fila = guardar(nil)
    fila.header_sample.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'Factura A1.pdf',
                              content_type: 'application/pdf')

    header = described_class.for(channel, 'factura', 'es_MX')

    expect(header.processed_header['preview_url']).to include('/rails/active_storage/blobs/redirect/')
    expect(header.processed_header['preview_url']).not_to eq(header.processed_header['media_url'])
  end

  it 'si no hay del mismo idioma usa el que haya' do
    guardar('https://cdn.mx/f.pdf', language: 'es')

    expect(described_class.for(channel, 'factura', 'es_MX').media[:url]).to eq('https://cdn.mx/f.pdf')
  end

  it 'sin archivo guardado no se puede mandar y dice por qué' do
    header = described_class.for(channel, 'factura', 'es_MX')

    expect(header.error).to include('no tiene archivo guardado')
    expect(TrackingDelivery.error_attributes(header.external_error))
      .to include(error_code: described_class::MISSING_CODE, error_kind: 'config')
  end

  it 'fuera de WhatsApp Cloud no se puede mandar el archivo' do
    channel.update_columns(provider: 'default') # rubocop:disable Rails/SkipsModelValidations
    guardar('https://cdn.mx/f.pdf')

    expect(described_class.for(channel.reload, 'factura', 'es_MX').error).to include('solo WhatsApp Cloud')
  end
end
