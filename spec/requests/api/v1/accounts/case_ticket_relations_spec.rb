# frozen_string_literal: true

require 'rails_helper'

# Pestaña «Casos relacionados»: crear un caso de cualquier tipo dentro de otro y ligar uno
# existente como «relacionado».
RSpec.describe 'Case ticket relations API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:venta) { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#0ea5e9', case_class: :support) }
  let(:opportunity) { CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta) }
  let(:url) { "/api/v1/accounts/#{account.id}/case_tickets/#{opportunity.id}/relations" }

  before { CaseSetting.for_account(account).update!(organization_rules: {}) }

  it 'crea un caso de otro tipo dentro de la oportunidad: hereda el contacto y queda como hijo' do
    post url, params: { case_type_id: soporte.id, title: 'Instalar licencias' }, headers: admin.create_new_auth_token,
              as: :json
    expect(response).to have_http_status(:created)
    rel = response.parsed_body['case_ticket_relation']
    expect(rel).to include('relation_type' => 'parent_child', 'direction' => 'outgoing')
    expect(rel['ticket']).to include('title' => 'Instalar licencias', 'case_class' => 'support')
    child = CaseTicket.find(rel['ticket']['id'])
    expect(child.contact).to eq(contact)
  end

  it 'liga uno existente como relacionado y lo devuelve con su estado' do
    other = CaseTicket.create!(account: account, title: 'Otro', contact: contact, case_type: soporte)
    post url, params: { related_ticket_id: other.id, relation_type: 'related' }, headers: admin.create_new_auth_token,
              as: :json
    expect(response).to have_http_status(:created)
    get url, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['case_ticket_relations'].first)
      .to include('relation_type' => 'related', 'ticket' => hash_including('id' => other.id, 'status' => 'open'))
  end
end
