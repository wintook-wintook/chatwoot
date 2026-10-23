# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — ligar (o crear) la conversación de un caso que nació sin ella.
RSpec.describe 'Case Conversations API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:ticket)  { CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte) }

  def link(params, target = ticket)
    post "/api/v1/accounts/#{account.id}/case_tickets/#{target.id}/conversation",
         params: params, headers: admin.create_new_auth_token, as: :json
  end

  it 'liga una conversación del contacto por su display_id y lo anota en la línea de tiempo' do
    conversation = create(:conversation, account: account, contact: contact)
    link(conversation_id: conversation.display_id)

    expect(response).to have_http_status(:created)
    expect(ticket.reload.conversation).to eq(conversation)
    event = ticket.case_events.conversation_link.last
    expect(event.payload).to include('display_id' => conversation.display_id, 'created' => false)
  end

  it 'no liga una conversación de otro contacto' do
    other = create(:conversation, account: account, contact: create(:contact, account: account))
    link(conversation_id: other.display_id)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(ticket.reload.conversation).to be_nil
  end

  it 'no cambia la conversación de un caso que ya tiene una' do
    first = create(:conversation, account: account, contact: contact)
    ticket.update!(conversation: first)
    link(conversation_id: create(:conversation, account: account, contact: contact).display_id)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(ticket.reload.conversation).to eq(first)
  end

  it 'no deja dos casos abiertos de la misma clase en una conversación' do
    conversation = create(:conversation, account: account, contact: contact)
    CaseTicket.create!(account: account, title: 'Otra falla', contact: contact, case_type: soporte,
                       conversation: conversation)
    link(conversation_id: conversation.display_id)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('ya tiene el caso')
  end

  it 'sí deja un caso de otra clase en la misma conversación' do
    conversation = create(:conversation, account: account, contact: contact)
    CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta,
                       conversation: conversation)
    link(conversation_id: conversation.display_id)

    expect(response).to have_http_status(:created)
  end

  it 'con una bandeja reusa la conversación abierta del contacto en ella' do
    conversation = create(:conversation, account: account, contact: contact, status: :open)
    expect { link(inbox_id: conversation.inbox_id) }.not_to change(Conversation, :count)

    expect(response).to have_http_status(:created)
    expect(ticket.reload.conversation).to eq(conversation)
  end

  it 'con una bandeja sin conversación abierta crea una nueva' do
    inbox = create(:inbox, account: account, channel: create(:channel_api, account: account))
    expect { link(inbox_id: inbox.id) }.to change(Conversation, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['created']).to be(true)
    expect(ticket.reload.conversation.inbox).to eq(inbox)
  end

  it 'pide un contacto si el caso no tiene' do
    internal = CaseTicket.create!(account: account, title: 'Interno', case_type: soporte, origin: :internal,
                                  requester: admin)
    link({ conversation_id: 1 }, internal)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('contacto')
  end
end
