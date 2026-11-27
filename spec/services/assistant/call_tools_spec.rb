# frozen_string_literal: true

require 'rails_helper'

# Dali — llamar por WhatsApp: la tarjeta revisa que se pueda y el navegador hace la llamada.
RSpec.describe Assistant::CallTools do
  let(:account) { create(:account, locale: 'es') }
  let(:channel) { calling_channel(account: account) }
  let(:inbox) { channel.inbox }
  let(:admin_user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez', phone_number: '+5215512345678') }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def tools_for(user, grant) = Assistant::Tools.new(account: account, user: user, grant: grant, zone: Time.zone)
  def executor_for(user, grant) = Assistant::Executor.new(account: account, user: user, grant: grant, zone: Time.zone)

  it 'propone la llamada con la conversación de WhatsApp del contacto y, al confirmar, manda lo que necesita el navegador' do
    proposal = tools_for(admin_user, admin).call('propose_whatsapp_call', { 'contact_id' => contact.id })[:proposal]
    expect(proposal).to include('type' => 'whatsapp_call', 'payload' => { 'conversation_id' => conversation.display_id })
    expect(proposal['labels']).to include('target' => 'Mario Pérez')
    expect(proposal['labels']['rows']).to include(['PHONE', '+5215512345678'])

    result = executor_for(admin_user, admin).call('whatsapp_call', proposal['payload'])
    expect(result['call']).to include('id' => conversation.display_id, 'inbox_id' => inbox.id)
    expect(result['call'].dig('meta', 'sender', 'name')).to eq('Mario Pérez')
    expect(result['label']).to eq('Llamando a Mario Pérez por WhatsApp')
  end

  it 'desde un caso llama a su cliente' do
    ticket = CaseTicket.create!(account: account, title: 'Paneles', contact: contact)
    proposal = tools_for(admin_user, admin).call('propose_whatsapp_call', { 'case_id' => ticket.id })[:proposal]
    expect(proposal['payload']).to eq('conversation_id' => conversation.display_id)
  end

  it 'una bandeja de solo entrantes no llama' do
    channel.update_columns(provider_config: channel.provider_config.merge('calling_direction' => 'inbound')) # rubocop:disable Rails/SkipsModelValidations
    result = tools_for(admin_user, admin).call('propose_whatsapp_call', { 'conversation_id' => conversation.display_id })[:result]
    expect(result[:error]).to include('no tiene activadas las llamadas salientes')
  end

  it 'sin conversación de WhatsApp con llamadas dice qué hacer' do
    otro = create(:contact, account: account, name: 'Sin chat')
    result = tools_for(admin_user, admin).call('propose_whatsapp_call', { 'contact_id' => otro.id })[:result]
    expect(result[:error]).to include('no tiene una conversación de WhatsApp')
  end

  it 'solo los usuarios de la bandeja y los administradores' do
    agent = create(:user, account: account, role: :agent)
    au = account.account_users.find_by(user: agent)
    grant = Access::Grant.for(au)
    conversation.update!(assignee: agent) # que la vea
    result = tools_for(agent, grant).call('propose_whatsapp_call', { 'conversation_id' => conversation.display_id })[:result]
    expect(result[:error]).to include('Solo los usuarios de esa bandeja')

    create(:inbox_member, inbox: inbox, user: agent)
    expect(tools_for(agent, grant).call('propose_whatsapp_call', { 'conversation_id' => conversation.display_id })[:proposal]).to be_present
  end

  it 'al confirmar se vuelve a revisar (si ya no se puede, no llama)' do
    channel.update_columns(provider_config: channel.provider_config.merge('calling_enabled' => false)) # rubocop:disable Rails/SkipsModelValidations
    expect { executor_for(admin_user, admin).call('whatsapp_call', { 'conversation_id' => conversation.display_id }) }
      .to raise_error(Assistant::Executor::Refused, /no tiene activadas/)
  end
end
