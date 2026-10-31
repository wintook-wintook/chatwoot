# frozen_string_literal: true

require 'rails_helper'

# feat/plantillas_whatsapp_mejoras F1 — envío de plantillas por WhatsApp Cloud con todos sus
# components (docs/plantillas_whatsapp_mejoras_plan.md §3–§4). Se compara el JSON EXACTO que
# llega a Meta: lo que hoy se envía tiene que seguir saliendo igual.
describe Whatsapp::SendOnWhatsappService do
  let(:messages_url) { 'https://graph.facebook.com/v20.0/123456789/messages' }
  let(:plantillas) do
    [
      { 'name' => 'sample_shipping_confirmation', 'status' => 'approved', 'language' => 'en_US', 'namespace' => 'ns1',
        'components' => [{ 'type' => 'BODY', 'text' => 'Your package has been shipped. It will be delivered in {{1}} business days.' },
                         { 'type' => 'FOOTER', 'text' => 'This message is from an unverified business.' }] },
      { 'name' => 'promo_imagen', 'status' => 'approved', 'language' => 'es_MX',
        'components' => [{ 'type' => 'HEADER', 'format' => 'IMAGE' }, { 'type' => 'BODY', 'text' => 'Hola {{1}}' }] },
      { 'name' => 'promo_video', 'status' => 'approved', 'language' => 'es_MX',
        'components' => [{ 'type' => 'HEADER', 'format' => 'VIDEO' }, { 'type' => 'BODY', 'text' => 'Mira esto' }] },
      { 'name' => 'factura', 'status' => 'approved', 'language' => 'es_MX',
        'components' => [{ 'type' => 'HEADER', 'format' => 'DOCUMENT' }, { 'type' => 'BODY', 'text' => 'Tu factura {{1}}' }] },
      { 'name' => 'pedido', 'status' => 'approved', 'language' => 'es_MX',
        'components' => [{ 'type' => 'HEADER', 'format' => 'TEXT', 'text' => 'Pedido {{1}}' },
                         { 'type' => 'BODY', 'text' => 'Gracias {{1}}' },
                         { 'type' => 'BUTTONS', 'buttons' => [{ 'type' => 'URL', 'url' => 'https://x.mx/{{1}}' },
                                                              { 'type' => 'COPY_CODE' }] }] },
      { 'name' => 'saludo_nombre', 'status' => 'approved', 'language' => 'es_MX', 'parameter_format' => 'NAMED',
        'components' => [{ 'type' => 'BODY', 'text' => 'Hola {{nombre}}' }] },
      { 'name' => 'saludo_sin_formato', 'status' => 'approved', 'language' => 'es_MX',
        'components' => [{ 'type' => 'BODY', 'text' => 'Hola {{nombre}}, tienes {{edad}}.' }] }
    ]
  end
  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false,
                              message_templates: plantillas)
  end
  let(:contact_inbox) { create(:contact_inbox, inbox: channel.inbox, source_id: '123456789') }
  let(:conversation) { create(:conversation, contact_inbox: contact_inbox, inbox: channel.inbox) }

  before do
    stub_request(:post, messages_url).to_return(status: 200, body: { messages: [{ id: 'wamid.1' }] }.to_json,
                                                headers: { 'Content-Type' => 'application/json' })
  end

  def send_template(name, language, processed_params)
    message = create(:message, message_type: :outgoing, content: 'plantilla', conversation: conversation,
                               additional_attributes: { template_params: { name: name, language: language,
                                                                           processed_params: processed_params } })
    described_class.new(message: message).perform
    message
  end

  # Los components que recibió Meta en el último envío.
  def sent_components
    body = nil
    expect(WebMock).to(have_requested(:post, messages_url).with { |req| body = JSON.parse(req.body) })
    body.dig('template', 'components')
  end

  it 'el formato viejo {"1": "3"} manda el mismo JSON que antes' do
    send_template('sample_shipping_confirmation', 'en_US', { '1' => '3' })

    expect(sent_components).to eq([{ 'type' => 'body', 'parameters' => [{ 'type' => 'text', 'text' => '3' }] }])
  end

  it 'una plantilla que no está en la lista de la bandeja sale como antes' do
    send_template('no_existe', 'es_MX', { '1' => 'Ana' })

    expect(sent_components).to eq([{ 'type' => 'body', 'parameters' => [{ 'type' => 'text', 'text' => 'Ana' }] }])
  end

  it 'manda la imagen del encabezado y las variables del cuerpo' do
    send_template('promo_imagen', 'es_MX', { 'header' => { 'media_url' => 'https://cdn.example.com/p.png', 'media_type' => 'image' },
                                             'body' => { '1' => 'Ana' } })

    expect(sent_components).to eq([
                                    { 'type' => 'header',
                                      'parameters' => [{ 'type' => 'image', 'image' => { 'link' => 'https://cdn.example.com/p.png' } }] },
                                    { 'type' => 'body', 'parameters' => [{ 'type' => 'text', 'text' => 'Ana' }] }
                                  ])
  end

  it 'manda un video sin variables en el cuerpo' do
    send_template('promo_video', 'es_MX', { 'header' => { 'media_url' => 'https://cdn.example.com/v.mp4', 'media_type' => 'video' } })

    expect(sent_components).to eq([{ 'type' => 'header',
                                     'parameters' => [{ 'type' => 'video', 'video' => { 'link' => 'https://cdn.example.com/v.mp4' } }] }])
  end

  it 'el documento lleva su nombre de archivo' do
    send_template('factura', 'es_MX', { 'header' => { 'media_url' => 'https://cdn.example.com/f.pdf', 'media_type' => 'document',
                                                      'media_name' => 'Factura A1.pdf' },
                                        'body' => { '1' => 'A1' } })

    expect(sent_components.first).to eq('type' => 'header', 'parameters' => [
                                          { 'type' => 'document',
                                            'document' => { 'link' => 'https://cdn.example.com/f.pdf', 'filename' => 'Factura A1.pdf' } }
                                        ])
  end

  it 'encabezado de texto con variable, botón con liga variable y copiar código' do
    send_template('pedido', 'es_MX', { 'header' => { '1' => 'A1' }, 'body' => { '1' => 'Ana' },
                                       'buttons' => [{ 'type' => 'url', 'parameter' => 'A1' },
                                                     { 'type' => 'copy_code', 'parameter' => 'PROMO10' }] })

    expect(sent_components).to eq([
                                    { 'type' => 'header', 'parameters' => [{ 'type' => 'text', 'text' => 'A1' }] },
                                    { 'type' => 'body', 'parameters' => [{ 'type' => 'text', 'text' => 'Ana' }] },
                                    { 'type' => 'button', 'sub_type' => 'url', 'index' => 0,
                                      'parameters' => [{ 'type' => 'text', 'text' => 'A1' }] },
                                    { 'type' => 'button', 'sub_type' => 'copy_code', 'index' => 1,
                                      'parameters' => [{ 'type' => 'coupon_code', 'coupon_code' => 'PROMO10' }] }
                                  ])
  end

  # Rails quita los null de los arreglos: la posición tiene que viajar en cada botón.
  it 'el botón con dato sale con su posición real, aunque haya otro antes' do
    send_template('pedido', 'es_MX', { 'header' => { '1' => 'A1' }, 'body' => { '1' => 'Ana' },
                                       'buttons' => [{ 'type' => 'copy_code', 'index' => 1, 'parameter' => 'PROMO10' }] })

    expect(sent_components.last).to include('sub_type' => 'copy_code', 'index' => 1)
  end

  it 'variables con nombre van con parameter_name' do
    send_template('saludo_nombre', 'es_MX', { 'body' => { 'nombre' => 'Ana' } })

    expect(sent_components).to eq([{ 'type' => 'body',
                                     'parameters' => [{ 'type' => 'text', 'parameter_name' => 'nombre', 'text' => 'Ana' }] }])
  end

  # F9.2: la lista de Meta puede no traer parameter_format.
  it 'sin parameter_format, las variables con nombre se reconocen por el texto y conservan su orden' do
    send_template('saludo_sin_formato', 'es_MX', { 'nombre' => 'Ana', 'edad' => '34' })

    expect(sent_components).to eq([{ 'type' => 'body',
                                     'parameters' => [{ 'type' => 'text', 'parameter_name' => 'nombre', 'text' => 'Ana' },
                                                      { 'type' => 'text', 'parameter_name' => 'edad', 'text' => '34' }] }])
  end

  it 'D3: conserva las comillas del texto y quita solo < >' do
    send_template('promo_imagen', 'es_MX', { 'header' => { 'media_url' => 'https://cdn.example.com/p.png', 'media_type' => 'image' },
                                             'body' => { '1' => 'el "Plan Plus" <b>' } })

    expect(sent_components.last).to eq('type' => 'body', 'parameters' => [{ 'type' => 'text', 'text' => 'el "Plan Plus" b' }])
  end

  it 'un dato inválido deja el mensaje fallido con el motivo y no se envía' do
    message = send_template('pedido', 'es_MX', { 'body' => { '1' => 'Ana' },
                                                 'buttons' => [nil, { 'type' => 'copy_code', 'parameter' => 'CODIGO_DEMASIADO_LARGO' }] })

    expect(message.reload).to have_attributes(status: 'failed', external_error: include('15'))
    expect(WebMock).not_to have_requested(:post, messages_url)
  end

  # El agente manda el archivo guardado de la plantilla: la liga para Meta se saca al enviar.
  describe 'con el archivo de la plantilla (source: template)' do
    let(:fila) do
      create(:whatsapp_template, channel_whatsapp: channel, account: channel.account, name: 'factura', language: 'es_MX',
                                 header_type: 'document')
    end

    it 'manda una liga fresca del archivo y guarda en el mensaje la que no caduca' do
      fila.header_sample.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'Factura A1.pdf',
                                content_type: 'application/pdf')

      message = send_template('factura', 'es_MX', { 'header' => { 'source' => 'template', 'media_type' => 'document' },
                                                    'body' => { '1' => 'A1' } })

      documento = sent_components.first['parameters'].first['document']
      expect(documento['link']).to include('/rails/active_storage/')
      expect(documento['filename']).to eq('Factura A1.pdf')

      guardado = message.reload.additional_attributes.dig('template_params', 'processed_params', 'header')
      expect(guardado).to include('media_name' => 'Factura A1.pdf', 'media_type' => 'document')
      expect(guardado['preview_url']).to include('/rails/active_storage/blobs/redirect/')
      expect(guardado).not_to have_key('media_url')
    end

    it 'un archivo subido para este envío: liga fresca, su nombre y la liga que no caduca' do
      blob = ActiveStorage::Blob.create_and_upload!(io: Rails.root.join('spec/assets/sample.pdf').open,
                                                    filename: 'Cotizacion 77.pdf', content_type: 'application/pdf')

      message = send_template('factura', 'es_MX', { 'header' => { 'source' => 'upload', 'signed_id' => blob.signed_id,
                                                                  'media_type' => 'document' },
                                                    'body' => { '1' => 'A1' } })

      documento = sent_components.first['parameters'].first['document']
      expect(documento).to include('filename' => 'Cotizacion 77.pdf')
      expect(documento['link']).to include('/rails/active_storage/')
      guardado = message.reload.additional_attributes.dig('template_params', 'processed_params', 'header')
      expect(guardado['preview_url']).to include('/rails/active_storage/blobs/redirect/')
      expect(guardado).not_to have_key('media_url')
    end

    it 'un archivo subido que ya no existe deja el mensaje fallido' do
      message = send_template('factura', 'es_MX', { 'header' => { 'source' => 'upload', 'signed_id' => 'no-existe',
                                                                  'media_type' => 'document' },
                                                    'body' => { '1' => 'A1' } })

      expect(message.reload).to have_attributes(status: 'failed', external_error: include('vuelve a subirlo'))
      expect(WebMock).not_to have_requested(:post, messages_url)
    end

    it 'sin archivo guardado deja el mensaje fallido con el motivo y no se envía' do
      message = send_template('factura', 'es_MX', { 'header' => { 'source' => 'template', 'media_type' => 'document' },
                                                    'body' => { '1' => 'A1' } })

      expect(message.reload).to have_attributes(status: 'failed', external_error: include('no tiene archivo guardado'))
      expect(WebMock).not_to have_requested(:post, messages_url)
    end
  end

  describe Whatsapp::Providers::WhatsappCloudService do
    let(:service) { described_class.new(whatsapp_channel: channel) }

    it 'la lista de siempre (seguimientos, campañas) sigue yendo como un solo body' do
      componentes = service.send(:template_components, [{ type: 'text', text: 'Ana' }])

      expect(componentes).to eq([{ type: 'body', parameters: [{ type: 'text', text: 'Ana' }] }])
    end

    it 'sin parámetros, igual que antes' do
      expect(service.send(:template_components, nil)).to eq([{ type: 'body', parameters: nil }])
    end
  end
end
