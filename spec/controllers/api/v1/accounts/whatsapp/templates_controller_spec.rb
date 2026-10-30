# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — CRUD de plantillas (request spec).
RSpec.describe 'WhatsApp Templates API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { channel.inbox }

  before { account.enable_features!('whatsapp_templates') }

  describe 'GET /api/v1/accounts/{id}/whatsapp/templates' do
    let!(:template) { create(:whatsapp_template, account: account, channel_whatsapp: channel, name: 'cobro') }

    it 'rechaza a usuarios no autenticados' do
      get "/api/v1/accounts/#{account.id}/whatsapp/templates", params: { inbox_id: inbox.id }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rechaza a agentes' do
      get "/api/v1/accounts/#{account.id}/whatsapp/templates",
          params: { inbox_id: inbox.id }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rechaza si la feature está deshabilitada en la cuenta' do
      account.disable_features!('whatsapp_templates')
      get "/api/v1/accounts/#{account.id}/whatsapp/templates",
          params: { inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'lista las plantillas del canal para admins' do
      get "/api/v1/accounts/#{account.id}/whatsapp/templates",
          params: { inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body.map { |t| t[:name] }).to include('cobro')
    end
  end

  describe 'POST /api/v1/accounts/{id}/whatsapp/templates (DRY_RUN)' do
    before do
      allow(GlobalConfigService).to receive(:load).and_call_original
      allow(GlobalConfigService).to receive(:load).with('WHATSAPP_TEMPLATES_DRY_RUN', false).and_return('true')
    end

    let(:payload) do
      {
        inbox_id: inbox.id,
        whatsapp_template: {
          name: 'cobro_vencido', language: 'es', category: 'UTILITY',
          body_text: 'Hola {{1}}.', sample_values: { body: ['Juan'] }
        }
      }
    end

    it 'crea una plantilla PENDING sin llamar a Meta' do
      post "/api/v1/accounts/#{account.id}/whatsapp/templates",
           params: payload, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:status]).to eq('PENDING')
      expect(body[:meta_template_id]).to start_with('dry-run-')
    end

    # feat/plantillas_whatsapp_mejoras F10 (D10b)
    it 'con draft guarda un borrador sin llamar a Meta, y luego se edita y se manda' do
      payload[:whatsapp_template][:body_text] = 'a medias'
      post "/api/v1/accounts/#{account.id}/whatsapp/templates",
           params: payload.merge(draft: true), headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      borrador = response.parsed_body
      expect(borrador).to include('status' => 'DRAFT', 'editable' => true, 'local_only' => true)
      # F10: la lista muestra quién la creó y sus fechas.
      expect(borrador['created_by']).to include('id' => admin.id, 'name' => admin.name)
      expect(borrador).to include('created_at', 'updated_at')

      patch "/api/v1/accounts/#{account.id}/whatsapp/templates/#{borrador['id']}",
            params: { whatsapp_template: { body_text: 'Hola {{1}}.', sample_values: { body: ['Juan'] } } },
            headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('PENDING')
    end

    it 'devuelve 422 con error por campo si es inválido' do
      payload[:whatsapp_template][:name] = 'Mal Nombre'
      post "/api/v1/accounts/#{account.id}/whatsapp/templates",
           params: payload, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/Nombre/)
    end
  end

  # feat/plantillas_whatsapp_mejoras F6: subir el archivo de muestra del encabezado.
  # feat/plantillas_whatsapp_mejoras: el modal de borrar avisa dónde se usa.
  describe 'GET /api/v1/accounts/{id}/whatsapp/templates/:id/usage' do
    let(:template) { create(:whatsapp_template, channel_whatsapp: inbox.channel, account: account) }

    it 'dice dónde se usa, solo a administradores' do
      get "/api/v1/accounts/#{account.id}/whatsapp/templates/#{template.id}/usage", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('agents' => [], 'trackings_count' => 0, 'campaigns' => [], 'portals' => [])

      agente = create(:user, account: account, role: :agent)
      get "/api/v1/accounts/#{account.id}/whatsapp/templates/#{template.id}/usage", headers: agente.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/accounts/{id}/whatsapp/templates/header_samples' do
    let(:url) { "/api/v1/accounts/#{account.id}/whatsapp/templates/header_samples" }

    it 'guarda un PDF para un encabezado de documento y devuelve su signed_id' do
      post url, params: { header_type: 'document', file: fixture_file_upload('spec/assets/sample.pdf', 'application/pdf') },
                headers: admin.create_new_auth_token

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body).to include('filename' => 'sample.pdf', 'content_type' => 'application/pdf')
      expect(ActiveStorage::Blob.find_signed(body['signed_id'])).to be_present
      expect(body['url']).to include('/rails/active_storage/')
    end

    it 'rechaza un tipo que Meta no acepta para ese encabezado' do
      post url, params: { header_type: 'document', file: fixture_file_upload('spec/assets/sample.png', 'image/png') },
                headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Tipo no permitido (image/png); solo PDF')
    end

    it 'sin archivo o con un tipo de encabezado raro no guarda nada' do
      post url, params: { header_type: 'document' }, headers: admin.create_new_auth_token
      expect(response.parsed_body['error']).to eq('Falta el archivo')

      post url, params: { header_type: 'text', file: fixture_file_upload('spec/assets/sample.pdf', 'application/pdf') },
                headers: admin.create_new_auth_token
      expect(response.parsed_body['error']).to eq('Tipo de encabezado no válido')
    end

    it 'agentes no pueden subir' do
      post url, params: { header_type: 'document', file: fixture_file_upload('spec/assets/sample.pdf', 'application/pdf') },
                headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end

    it 'al crear la plantilla el archivo subido queda pegado y cuenta como su muestra' do
      allow(GlobalConfigService).to receive(:load).and_call_original
      allow(GlobalConfigService).to receive(:load).with('WHATSAPP_TEMPLATES_DRY_RUN', false).and_return('true')
      post url, params: { header_type: 'document', file: fixture_file_upload('spec/assets/sample.pdf', 'application/pdf') },
                headers: admin.create_new_auth_token
      signed_id = response.parsed_body['signed_id']

      post "/api/v1/accounts/#{account.id}/whatsapp/templates",
           params: { inbox_id: inbox.id, whatsapp_template: { name: 'factura', language: 'es', category: 'UTILITY',
                                                              header_type: 'document', header_sample: signed_id,
                                                              body_text: 'Tu factura' } },
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      # F10.4: también su signed_id, para que «Duplicar» pegue el mismo archivo.
      expect(response.parsed_body['header_sample']).to include('filename' => 'sample.pdf', 'signed_id' => signed_id)
      expect(WhatsappTemplate.find(response.parsed_body['id']).header_sample).to be_attached
    end
  end

  describe 'POST /api/v1/accounts/{id}/whatsapp/templates/sync' do
    it 'reconcilia desde Meta y devuelve el conteo' do
      allow_any_instance_of(Whatsapp::TemplateSyncService).to receive(:perform)
        .and_return(Whatsapp::TemplateSyncService::Result.new(synced: 3, created: 2, updated: 1))

      post "/api/v1/accounts/#{account.id}/whatsapp/templates/sync",
           params: { inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to include('synced' => 3, 'created' => 2, 'updated' => 1)
    end

    it 'devuelve 422 con el motivo real cuando Meta falla' do
      allow_any_instance_of(Whatsapp::TemplateSyncService).to receive(:perform)
        .and_raise('Meta respondió 401: Session has expired')

      post "/api/v1/accounts/#{account.id}/whatsapp/templates/sync",
           params: { inbox_id: inbox.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/Session has expired/)
    end
  end

  describe 'POST /api/v1/accounts/{id}/whatsapp/templates/import' do
    it 'importa desde el cache del canal (message_templates) sin llamar a Meta' do
      channel.update_column(:message_templates, [
                              { 'id' => '900', 'name' => 'aprobada_x', 'language' => 'es', 'category' => 'UTILITY',
                                'status' => 'APPROVED', 'components' => [{ 'type' => 'BODY', 'text' => 'Hola' }] }
                            ])

      post "/api/v1/accounts/#{account.id}/whatsapp/templates/import",
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(account.whatsapp_templates.find_by(name: 'aprobada_x')).to have_attributes(status: 'APPROVED')
    end
  end

  describe 'DELETE /api/v1/accounts/{id}/whatsapp/templates/{id}' do
    it 'borra una plantilla local-only' do
      template = create(:whatsapp_template, account: account, channel_whatsapp: channel, meta_template_id: nil)

      delete "/api/v1/accounts/#{account.id}/whatsapp/templates/#{template.id}",
             headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(WhatsappTemplate.exists?(template.id)).to be(false)
    end
  end
end
