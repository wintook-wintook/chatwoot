# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F6) — la pestaña «Llamadas» de una bandeja.
RSpec.describe 'Configuración de llamadas de una bandeja' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel) do
    account.enable_features!('whatsapp_calls')
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:url) { "/api/v1/accounts/#{account.id}/inboxes/#{channel.inbox.id}/whatsapp_call_settings" }
  let(:meta) { instance_double(Whatsapp::Providers::WhatsappCloudService, update_calling_status: true, calling_settings: { 'status' => 'NOT_SET' }) }

  before { allow_any_instance_of(Channel::Whatsapp).to receive(:calls_provider).and_return(meta) } # rubocop:disable RSpec/AnyInstance

  def guardar(params)
    patch url, params: params, headers: admin.create_new_auth_token, as: :json
  end

  it 'muestra lo que hay y el estado en Meta' do
    get url, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to include('feature_enabled' => true, 'enabled' => false, 'direction' => 'both',
                                            'ring_strategy' => 'cascade', 'meta_status' => { 'status' => 'NOT_SET' })
  end

  it 'solo administradores' do
    agente = create(:user, account: account, role: :agent)
    get url, headers: agente.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'una bandeja unoapi no tiene llamadas' do
    otra = create(:channel_whatsapp, account: account, provider: 'unoapi', sync_templates: false, validate_provider_config: false)
    get "/api/v1/accounts/#{account.id}/inboxes/#{otra.inbox.id}/whatsapp_call_settings", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'prender habla con Meta y guarda el tipo; las bandejas a mano quedan con aviso de webhook' do
    guardar(enabled: true, direction: 'outbound', ring_strategy: 'all_online', call_permission_request_body: '¿Te llamamos?')

    expect(meta).to have_received(:update_calling_status).with('ENABLED', icon: 'DISABLE_ALL')
    expect(response.parsed_body).to include('enabled' => true, 'direction' => 'outbound', 'ring_strategy' => 'all_online',
                                            'call_permission_request_body' => '¿Te llamamos?', 'calls_webhook' => 'manual')
  end

  it 'si Meta no deja, responde 422 con su mensaje y no queda prendida' do
    allow(meta).to receive(:update_calling_status).and_raise('Límite de mensajería insuficiente')

    guardar(enabled: true)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('Límite de mensajería insuficiente')
    expect(channel.reload.provider_config['calling_enabled']).to be_nil
  end

  it 'cambiar el tipo estando prendida vuelve a avisar a Meta; cambiar a quién suena no' do
    guardar(enabled: true, direction: 'both')
    guardar(ring_strategy: 'all_online')
    expect(meta).to have_received(:update_calling_status).once

    guardar(direction: 'outbound')
    expect(meta).to have_received(:update_calling_status).with('ENABLED', icon: 'DISABLE_ALL')
  end

  # F7: la grabación y su aviso se guardan sin tocar Meta
  it 'grabar y el texto del aviso' do
    guardar(recording_enabled: true, recording_notice: '  Grabamos esta llamada.  ')

    expect(response.parsed_body).to include('recording_enabled' => true, 'recording_notice' => 'Grabamos esta llamada.',
                                            'default_recording_notice' => I18n.t('conversations.messages.whatsapp.call_recording_notice'))
    expect(meta).not_to have_received(:update_calling_status)
  end

  # F8: qué hacer con una llamada perdida; solo opciones de la propia cuenta
  it 'las acciones de llamada perdida y lo que se puede elegir' do
    tipo = CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
    ajeno = CaseType.create!(account: create(:account), name: 'Otro', color: '#3b82f6')
    campana = create(:tracking_campaign, account: account)

    guardar(missed_call_actions: %w[note ticket borrar_todo], missed_call_case_type_id: ajeno.id,
            missed_call_campaign_id: campana.id, missed_call_label: 'perdidas')
    expect(response.parsed_body).to include('missed_call_actions' => %w[note ticket], 'missed_call_case_type_id' => nil,
                                            'missed_call_campaign_id' => campana.id, 'missed_call_label' => 'perdidas')

    guardar(missed_call_case_type_id: tipo.id)
    expect(response.parsed_body['missed_call_case_type_id']).to eq(tipo.id)
    expect(response.parsed_body['missed_call_options']['case_types']).to include('id' => tipo.id, 'name' => 'Soporte')
    expect(response.parsed_body['missed_call_options']['campaigns'].pluck('id')).to eq([campana.id])
  end

  it 'el tono del timbre: uno de la lista; uno inventado no se guarda' do
    guardar(ringtone: 'classic')
    expect(response.parsed_body['ringtone']).to eq('classic')

    guardar(ringtone: 'whatsapp-original.mp3')
    expect(response.parsed_body['ringtone']).to eq('classic')
  end

  it 'apagar' do
    guardar(enabled: true)
    guardar(enabled: false)

    expect(response.parsed_body['enabled']).to be(false)
    expect(meta).to have_received(:update_calling_status).with('DISABLED')
  end
end
