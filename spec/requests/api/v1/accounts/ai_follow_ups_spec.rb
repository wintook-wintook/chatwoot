# frozen_string_literal: true

require 'rails_helper'

# Seguimiento IA — delegar desde el caso (API) y desde Dali (tarjeta «Confirmar»).
RSpec.describe 'AI follow-ups API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Cotización', contact: contact, case_type: soporte, conversation: conversation) }
  let(:base) { "/api/v1/accounts/#{account.id}/ai_follow_ups" }

  it 'delega desde el caso, lo lista, lo pausa y lo cancela' do
    post base, params: { case_id: ticket.id, conversation_id: conversation.display_id, objective: 'Que confirme',
                         max_attempts: 2, interval_value: 1, interval_unit: 'days', tz: 'America/Mexico_City' },
               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    id = response.parsed_body.dig('payload', 'id')
    expect(AiFollowUp.find(id)).to have_attributes(case_ticket_id: ticket.id, max_attempts: 2, time_zone: 'America/Mexico_City')
    expect(ticket.case_events.where(event_type: :tracking_triggered)).to exist

    get base, params: { case_id: ticket.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['payload'].first['status']).to eq('active')

    get base, params: { contact_id: contact.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['payload'].pluck('id')).to eq([id])

    post "#{base}/#{id}/pause", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('payload', 'status')).to eq('paused')

    post "#{base}/#{id}/cancel", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('payload', 'status')).to eq('cancelled')
  end

  it 'lista las plantillas de WhatsApp que el agente puede usar y deja fijar una' do
    channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false,
                                        validate_provider_config: false,
                                        message_templates: [
                                          { 'name' => 'retomar', 'status' => 'APPROVED', 'category' => 'UTILITY', 'language' => 'es_MX',
                                            'components' => [{ 'type' => 'BODY', 'text' => 'Hola {{1}}' }] },
                                          { 'name' => 'con_video', 'status' => 'APPROVED', 'category' => 'MARKETING', 'language' => 'es_MX',
                                            'components' => [{ 'type' => 'HEADER', 'format' => 'VIDEO' }, { 'type' => 'BODY', 'text' => 'Mira' }] }
                                        ])
    wa = create(:conversation, account: account, inbox: channel.inbox, contact: contact)

    get "#{base}/templates", params: { conversation_id: wa.display_id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['whatsapp']).to be(true)
    expect(response.parsed_body['payload'].pluck('name')).to eq(['retomar'])

    post base, params: { conversation_id: wa.display_id, objective: 'Que confirme', template_name: 'retomar', template_language: 'es_MX' },
               headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('payload', 'template_name')).to eq('retomar')
  end

  describe 'contacto sin conversaciones' do
    let(:lonely) { create(:contact, account: account, name: 'Ana Ruiz', phone_number: '+5215512345678') }
    let(:channel) do
      create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                                message_templates: [{ 'name' => 'retomar', 'status' => 'APPROVED', 'category' => 'UTILITY',
                                                      'language' => 'es_MX',
                                                      'components' => [{ 'type' => 'BODY', 'text' => 'Hola {{1}}' }] }])
    end

    it 'ofrece las bandejas por las que se le puede escribir, con WhatsApp primero' do
      create(:inbox, account: account, channel: create(:channel_email, account: account))
      channel
      get "#{base}/inboxes", params: { contact_id: lonely.id }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['payload'].pluck('channel_type')).to eq(['Channel::Whatsapp'])
    end

    it 'abre la conversación en la bandeja elegida, asignada a quien delega, y arranca ahí' do
      get "#{base}/templates", params: { contact_id: lonely.id, inbox_id: channel.inbox.id }, headers: admin.create_new_auth_token,
                               as: :json
      expect(response.parsed_body['payload'].pluck('name')).to eq(['retomar'])

      post base, params: { contact_id: lonely.id, inbox_id: channel.inbox.id, objective: 'Que agende la visita',
                           template_name: 'retomar', template_language: 'es_MX' },
                 headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      conversation = lonely.conversations.sole
      expect(conversation).to have_attributes(inbox_id: channel.inbox.id, assignee_id: admin.id)
      expect(AiFollowUp.find(response.parsed_body.dig('payload', 'id'))).to have_attributes(conversation_id: conversation.id,
                                                                                            template_name: 'retomar')
    end

    it 'si falta el objetivo no deja una conversación vacía' do
      post base, params: { contact_id: lonely.id, inbox_id: channel.inbox.id, objective: '' },
                 headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(lonely.conversations).to be_empty
    end
  end

  it 'dice si hay respuestas predefinidas y da la nota IA del contacto' do
    create(:canned_response, account: account, short_code: 'horario', content: 'De 9 a 18 h')
    create(:note, account: account, user: admin, contact: contact, content: 'Prefiere WhatsApp', is_for_ia: true)

    get "#{base}/context", params: { conversation_id: conversation.display_id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['canned']).to be(true)
    expect(response.parsed_body.dig('ai_note', 'content')).to eq('Prefiere WhatsApp')
  end

  it 'sin objetivo no delega' do
    post base, params: { case_id: ticket.id, conversation_id: conversation.display_id, objective: '' },
               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'Dali propone y, al confirmar, crea el Seguimiento IA' do
    tools = Assistant::Tools.new(account: account, user: admin, grant: Access::Grant.for(admin.account_users.first),
                                 zone: ActiveSupport::TimeZone['America/Mexico_City'])
    outcome = tools.call('propose_follow_up', 'case_id' => ticket.id, 'objective' => 'Que confirme la cotización')
    expect(outcome[:proposal]['type']).to eq('follow_up')

    executor = Assistant::Executor.new(account: account, user: admin, grant: Access::Grant.for(admin.account_users.first),
                                       zone: ActiveSupport::TimeZone['America/Mexico_City'])
    executor.call('follow_up', outcome[:proposal]['payload'])
    expect(AiFollowUp.last).to have_attributes(objective: 'Que confirme la cotización', case_ticket_id: ticket.id,
                                               created_by_id: admin.id, status: 'active')
  end
end
