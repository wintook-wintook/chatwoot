# frozen_string_literal: true

require 'rails_helper'

# «Ligar a un cliente»: el caso interno pasa a ser de un contacto y su organización.
RSpec.describe 'Ligar un caso interno a un cliente' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, name: 'Mario López', organization: organization) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) do
    CaseTicket.create!(account: account, title: 'Revisar red', requester: admin, origin: :internal, case_type: type)
  end
  let(:url) { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/assign_client" }

  it 'toma el contacto y su organización, deja de ser interno y queda en la actividad' do
    patch url, params: { contact_id: contact.id }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['case_ticket']).to include('is_internal' => false, 'organization_id' => organization.id)
    expect(ticket.reload).to have_attributes(contact_id: contact.id, organization_id: organization.id, origin: 'manual',
                                             requester_id: admin.id)
    event = ticket.case_events.find_by(event_type: :client_assigned)
    expect(event.payload).to include('organization' => 'Acme', 'contact' => 'Mario López')
  end

  it 'también con el caso cerrado' do
    ticket.update!(status: :closed)
    patch url, params: { contact_id: contact.id, organization_id: organization.id }, headers: admin.create_new_auth_token, as: :json
    expect(ticket.reload.contact_id).to eq(contact.id)
  end

  it 'pide el contacto, que sea de la organización elegida, y solo a casos internos' do
    patch url, params: {}, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['error']).to include('contacto')

    other = Organization.create!(account: account, name: 'Otra')
    patch url, params: { contact_id: contact.id, organization_id: other.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['error']).to include('otra organización')
    expect(ticket.reload).to be_internal

    ticket.update!(contact: contact, origin: :manual)
    patch url, params: { contact_id: contact.id }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
