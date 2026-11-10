# frozen_string_literal: true

require 'rails_helper'

# Lista y tablero de casos: el robot del agente y los filtros «Con agente» / «Sin agente».
RSpec.describe 'Case tickets agent status' do
  let(:account) { create(:account) }
  let!(:attended) do
    a_case('Atendido').tap do |t|
      AiFollowUp.create!(account: account, conversation: t.conversation, case_ticket: t, objective: 'Que confirme')
    end
  end
  let!(:alone) { a_case('Solo') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:base) { "/api/v1/accounts/#{account.id}/case_tickets" }

  def a_case(title)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    CaseTicket.create!(account: account, title: title, contact: contact, case_type: soporte, conversation: conversation, assignee: admin)
  end

  it 'cada caso trae su robot y se filtra con agente / sin agente' do
    get base, params: { quick: 'all' }, headers: admin.create_new_auth_token, as: :json
    agents = response.parsed_body['case_tickets'].to_h { |t| [t['id'], t.dig('agent', 'state')] }
    expect(agents).to include(attended.id => 'active', alone.id => 'none')

    get base, params: { quick: 'all', agent: 'with' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['case_tickets'].pluck('id')).to eq([attended.id])

    get base, params: { quick: 'all', agent: 'none' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['case_tickets'].pluck('id')).to eq([alone.id])
  end
end
