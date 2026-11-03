# frozen_string_literal: true

require 'rails_helper'

# fix/mensajes_programados — de punta a punta, con lo que manda la pantalla
# (ScheduleMessageModal.vue + api/scheduledMessages.js).
RSpec.describe 'Mensajes programados' do
  let(:account) { create(:account) }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                              message_templates: [{ 'name' => 'pago', 'status' => 'approved', 'language' => 'es_MX', 'category' => 'UTILITY',
                                                    'components' => [{ 'type' => 'BODY', 'text' => 'Hola {{1}}' }] }])
  end
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox) }
  let(:url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/scheduled_messages" }
  let(:plantilla) do
    { content: 'Hola Juan', scheduled_at: 1.hour.from_now.iso8601, timezone: 'America/Mexico_City', message_type: 'outgoing',
      template_name: 'pago', template_category: 'UTILITY', template_language: 'es_MX', template_namespace: nil,
      template_params: { name: 'pago', category: 'UTILITY', language: 'es_MX', namespace: nil, processed_params: { '1' => 'Juan' } } }
  end

  before { create(:inbox_member, user: agente, inbox: channel.inbox) }

  def crear(cuerpo)
    post url, params: cuerpo, headers: agente.create_new_auth_token, as: :json
  end

  it 'crea un mensaje normal' do
    crear(content: 'Hola', scheduled_at: 1.hour.from_now.iso8601, timezone: 'UTC', message_type: 'outgoing')

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('content' => 'Hola', 'is_template' => false, 'sent' => false)
  end

  it 'crea una plantilla con los datos de la pantalla' do
    crear(plantilla)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('is_template' => true, 'template_name' => 'pago', 'template_language' => 'es_MX')
    expect(ScheduledMessage.last.template_params).to eq('1' => 'Juan')
  end

  it 'una plantilla incompleta se rechaza con el motivo' do
    crear(plantilla.except(:template_language, :template_category).merge(template_params: { name: 'pago' }))

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'lista, y se puede cancelar' do
    crear(plantilla)
    id = response.parsed_body['id']

    get url, headers: agente.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.pluck('id')).to include(id)

    delete "/api/v1/accounts/#{account.id}/scheduled_messages/#{id}", headers: agente.create_new_auth_token, as: :json
    expect(response).to have_http_status(:no_content)
    expect(ScheduledMessage.exists?(id)).to be(false)
  end

  it 'el job la entrega y sale a Meta con sus parámetros' do
    envio = stub_request(:post, %r{graph\.facebook\.com/.*/messages})
            .to_return(status: 200, body: { messages: [{ id: 'wamid.1' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
    crear(plantilla)
    ScheduledMessage.last.update_column(:scheduled_at, 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations

    ScheduledMessagesDeliveryJob.perform_now
    expect(ScheduledMessage.last.sent).to be(true)

    Whatsapp::SendOnWhatsappService.new(message: conversation.messages.outgoing.last).perform

    expect(envio.with do |req|
      cuerpo = JSON.parse(req.body)
      cuerpo.dig('template', 'name') == 'pago' &&
        cuerpo.dig('template', 'components', 0, 'parameters', 0, 'text') == 'Juan'
    end).to have_been_made
  end

  # feat/plantillas_variables_nombre F4: plantillas con archivo y botones.
  describe 'con archivo y botones' do
    let(:channel) do
      create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                                message_templates: [{ 'name' => 'pedido', 'status' => 'approved', 'language' => 'es_MX', 'category' => 'UTILITY',
                                                      'components' => [{ 'type' => 'HEADER', 'format' => 'DOCUMENT' },
                                                                       { 'type' => 'BODY', 'text' => 'Hola {{1}}.' },
                                                                       { 'type' => 'BUTTONS',
                                                                         'buttons' => [{ 'type' => 'QUICK_REPLY', 'text' => 'Si' },
                                                                                       { 'type' => 'URL', 'text' => 'Ver',
                                                                                         'url' => 'https://x.mx/{{1}}' }] }] }])
    end
    let(:processed) do
      { body: { '1' => 'Juan' }, header: { source: 'template', media_type: 'document' },
        buttons: [{ type: 'url', index: 1, parameter: 'A1' }] }
    end

    it 'guarda todo, lo manda al vencer con el archivo fresco y el botón en su posición' do
      create(:whatsapp_template, channel_whatsapp: channel, account: account, name: 'pedido', language: 'es_MX',
                                 header_type: 'document', header_media_url: 'https://cdn.mx/f.pdf')
      envio = stub_request(:post, %r{graph\.facebook\.com/.*/messages})
              .to_return(status: 200, body: { messages: [{ id: 'wamid.2' }] }.to_json, headers: { 'Content-Type' => 'application/json' })

      crear(plantilla.merge(template_name: 'pedido', template_params: { name: 'pedido', processed_params: processed }))

      expect(response).to have_http_status(:created)
      expect(ScheduledMessage.last.template_params).to include('buttons' => [{ 'type' => 'url', 'index' => 1, 'parameter' => 'A1' }])

      ScheduledMessage.last.update_column(:scheduled_at, 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations
      ScheduledMessagesDeliveryJob.perform_now
      Whatsapp::SendOnWhatsappService.new(message: conversation.messages.outgoing.last).perform

      expect(envio.with do |req|
        componentes = JSON.parse(req.body).dig('template', 'components')
        componentes.first.dig('parameters', 0, 'document', 'link') == 'https://cdn.mx/f.pdf' &&
          componentes.last.values_at('sub_type', 'index') == ['url', 1]
      end).to have_been_made
    end
  end
end
