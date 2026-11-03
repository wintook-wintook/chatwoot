# frozen_string_literal: true

require 'rails_helper'

# feat/plantillas_whatsapp_mejoras — el archivo guardado de una plantilla, para la conversación.
RSpec.describe 'Archivo guardado de una plantilla de WhatsApp' do
  let(:account) { create(:account) }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:plantillas) do
    [{ 'name' => 'factura', 'status' => 'approved', 'language' => 'es_MX',
       'components' => [{ 'type' => 'HEADER', 'format' => 'DOCUMENT' }, { 'type' => 'BODY', 'text' => 'Tu factura {{1}}.' }] },
     { 'name' => 'saludo', 'status' => 'approved', 'language' => 'es_MX',
       'components' => [{ 'type' => 'BODY', 'text' => 'Hola' }] }]
  end
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                              message_templates: plantillas)
  end

  before { create(:inbox_member, user: agente, inbox: channel.inbox) }

  def consultar(name, usuario: agente)
    get "/api/v1/accounts/#{account.id}/inboxes/#{channel.inbox.id}/whatsapp_template_header",
        params: { name: name, language: 'es_MX' }, headers: usuario.create_new_auth_token, as: :json
  end

  it 'un agente de la bandeja ve el archivo subido, con su nombre y una liga que no caduca' do
    fila = create(:whatsapp_template, channel_whatsapp: channel, account: account, name: 'factura', language: 'es_MX',
                                      header_type: 'document')
    fila.header_sample.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'Factura A1.pdf',
                              content_type: 'application/pdf')

    consultar('factura')

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('available' => true, 'media_type' => 'document', 'media_name' => 'Factura A1.pdf')
    expect(response.parsed_body['preview_url']).to include('/rails/active_storage/blobs/redirect/')
  end

  it 'lleva archivo y no hay guardado: dice por qué' do
    consultar('factura')

    expect(response.parsed_body).to include('available' => false, 'media_type' => 'document')
    expect(response.parsed_body['error']).to include('no tiene archivo guardado')
  end

  it 'una plantilla sin archivo no tiene nada que traer' do
    consultar('saludo')

    expect(response.parsed_body).to eq('available' => false, 'media_type' => nil)
  end

  describe 'subir otro archivo para este envío' do
    def subir(archivo, tipo, media_type: 'document')
      post "/api/v1/accounts/#{account.id}/inboxes/#{channel.inbox.id}/whatsapp_template_header",
           params: { media_type: media_type, file: Rack::Test::UploadedFile.new(Rails.root.join('spec/assets', archivo), tipo) },
           headers: agente.create_new_auth_token
    end

    it 'un agente sube un PDF y recibe su signed_id y una liga que no caduca' do
      subir('sample.pdf', 'application/pdf')

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('filename' => 'sample.pdf', 'signed_id' => be_present)
      expect(response.parsed_body['preview_url']).to include('/rails/active_storage/blobs/redirect/')
    end

    it 'un tipo que Meta no acepta se rechaza con el motivo' do
      subir('sample.pdf', 'application/pdf', media_type: 'image')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('solo JPEG/PNG')
    end
  end

  it 'un agente que no es de la bandeja no la ve' do
    otro = create(:user, account: account, role: :agent)
    consultar('factura', usuario: otro)

    expect(response).to have_http_status(:unauthorized)
  end
end
