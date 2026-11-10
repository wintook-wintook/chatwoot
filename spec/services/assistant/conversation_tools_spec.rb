# frozen_string_literal: true

require 'rails_helper'

# Dali — contestar conversaciones: cuáles esperan respuesta, leerlas y mandar la respuesta
# (texto libre dentro de las 24 h; plantilla aprobada fuera de ellas).
RSpec.describe Assistant::ConversationTools do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:templates) do
    [{ 'name' => 'retomar_cotizacion', 'status' => 'APPROVED', 'category' => 'UTILITY', 'language' => 'es_MX',
       'components' => [{ 'type' => 'BODY', 'text' => 'Hola {{1}}, ¿pudiste revisar la cotización {{2}}?' }] }]
  end
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', message_templates: templates,
                              sync_templates: false, validate_provider_config: false)
  end
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez', phone_number: '+5215512345678') }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, contact: contact, assignee: user) }

  def customer_says(text, at: 1.hour.ago)
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, message_type: :incoming,
                     content: text, created_at: at)
    conversation.update_columns(waiting_since: at) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'lista las que esperan respuesta, con su último mensaje' do
    customer_says('¿Ya llegó mi equipo?')
    create(:conversation, account: account, inbox: channel.inbox, assignee: user).update_columns(waiting_since: nil) # rubocop:disable Rails/SkipsModelValidations
    rows = tools.call('my_conversations', {})[:result]
    expect(rows[:total]).to eq(1)
    expect(rows[:conversations].first).to include(id: conversation.display_id, contact: 'Mario Pérez')
    expect(rows[:conversations].first[:last_message]).to include(from: 'cliente', text: '¿Ya llegó mi equipo?')
  end

  it 'lee la conversación y dice si se le puede escribir libre' do
    customer_says('¿Ya llegó mi equipo?')
    read = tools.call('read_conversation', { 'conversation_id' => conversation.display_id })[:result]
    expect(read[:can_reply]).to be(true)
    expect(read[:templates]).to be_nil
    expect(read[:messages].last).to include(from: 'Mario Pérez', text: '¿Ya llegó mi equipo?')
  end

  it 'dentro de las 24 h propone el texto y al confirmar lo manda a nombre del usuario' do
    customer_says('¿Ya llegó mi equipo?')
    proposal = tools.call('propose_reply', { 'conversation_id' => conversation.display_id, 'content' => 'Llega el jueves' })[:proposal]
    expect(proposal['labels']['conversation']).to include('Mario Pérez')

    result = executor.call('reply', proposal['payload'].merge('content' => 'Llega el jueves por la tarde'))
    message = conversation.messages.outgoing.last
    expect(message).to have_attributes(content: 'Llega el jueves por la tarde', sender: user, private: false)
    expect(result['label']).to include('Mario Pérez')
  end

  it 'fuera de las 24 h no deja texto libre y ofrece las plantillas' do
    customer_says('Lo reviso', at: 2.days.ago)
    error = tools.call('propose_reply', { 'conversation_id' => conversation.display_id, 'content' => 'Hola' })[:result][:error]
    expect(error).to include('24 h', 'retomar_cotizacion')
    expect(tools.call('read_conversation', { 'conversation_id' => conversation.display_id })[:result][:templates].first)
      .to include(name: 'retomar_cotizacion', variables: %w[1 2])
  end

  it 'con plantilla la llena, la muestra y al confirmar la manda' do
    customer_says('Lo reviso', at: 2.days.ago)
    proposal = tools.call('propose_reply', { 'conversation_id' => conversation.display_id, 'template_name' => 'retomar_cotizacion',
                                             'template_values' => { '1' => 'Mario', '2' => 'COT-0004' } })[:proposal]
    expect(proposal['labels']['template_text']).to eq('Hola Mario, ¿pudiste revisar la cotización COT-0004?')

    executor.call('reply', proposal['payload'])
    message = conversation.messages.outgoing.last
    expect(message.content).to eq('Hola Mario, ¿pudiste revisar la cotización COT-0004?')
    expect(message.additional_attributes.dig('template_params', 'name')).to eq('retomar_cotizacion')
  end

  it 'sin permiso de escribir en Conversaciones no propone ni manda' do
    customer_says('Hola')
    viewer = instance_double(Access::Grant, writable?: false, conversations: account.conversations)
    viewer_tools = Assistant::Tools.new(account: account, user: user, grant: viewer, zone: Time.zone)
    error = viewer_tools.call('propose_reply', { 'conversation_id' => conversation.display_id, 'content' => 'x' })[:result][:error]
    expect(error).to include('permiso')
    expect do
      Assistant::Executor.new(account: account, user: user, grant: viewer, zone: Time.zone)
                         .call('reply', { 'conversation_id' => conversation.display_id, 'content' => 'x' })
    end.to raise_error(Assistant::Executor::Refused)
  end
end
