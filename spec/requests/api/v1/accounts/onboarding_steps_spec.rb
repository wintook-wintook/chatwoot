# frozen_string_literal: true

require 'rails_helper'

# «Primeros pasos»: se revisan en vivo; los de administrador solo los ve un administrador.
RSpec.describe 'Onboarding steps' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/onboarding_steps" }

  def steps_for(user)
    get url, headers: user.create_new_auth_token
    response.parsed_body['steps'].to_h { |s| [s['key'], s['done']] }
  end

  it 'el administrador ve los 8 pasos y se palomean con lo que ya hizo' do
    expect(steps_for(admin).keys).to eq(%w[whatsapp team organization contact case meeting follow_up dali])
    expect(steps_for(admin).values).to all(be(false))

    organization = Organization.create!(account: account, name: 'Acme')
    create(:contact, account: account, organization_id: organization.id)
    create(:account_user, account: account, user: agent) unless agent.account_users.exists?(account: account)
    steps = steps_for(admin)
    expect(steps).to include('organization' => true, 'contact' => true, 'team' => true, 'case' => false)
  end

  it 'un agente no ve los pasos de administrador' do
    create(:account_user, account: account, user: agent) unless agent.account_users.exists?(account: account)
    expect(steps_for(agent).keys).to eq(%w[organization contact case meeting follow_up dali])
    expect(response.parsed_body).to include('done' => 0, 'total' => 6)
  end
end
