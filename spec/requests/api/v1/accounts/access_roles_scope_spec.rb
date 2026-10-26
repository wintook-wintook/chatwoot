# frozen_string_literal: true

require 'rails_helper'

# Plan-Roles-Permisos P1 — el candado va en el servidor: áreas, «solo lo suyo»,
# reasignar, montos y dashboards.
RSpec.describe 'Roles y permisos — alcance en el servidor' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:other)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:base)    { "/api/v1/accounts/#{account.id}" }

  def give_role(user, key)
    role = AccessRole.for_account(account).find { |r| r.key == key }
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  def ticket(type, assignee, attrs = {})
    CaseTicket.create!({ account: account, title: 'Caso', contact: contact, case_type: type, assignee: assignee }.merge(attrs))
  end

  def ids_for(user, params = {})
    get "#{base}/case_tickets", params: params, headers: user.create_new_auth_token, as: :json
    response.parsed_body['case_tickets'].pluck('id')
  end

  describe 'roles de la cuenta' do
    it 'crea las 4 plantillas una sola vez y un agente sin rol cuenta como Supervisor' do
      expect(AccessRole.for_account(account).map(&:key)).to eq(%w[supervisor seller technician viewer])
      expect { AccessRole.for_account(account) }.not_to change(AccessRole, :count)

      grant = Access::Grant.for(account.account_users.find_by(user: agent))
      expect(grant.role_key).to eq('supervisor')
      expect(grant.level(:sales)).to eq('all')
    end

    it '«Restaurar como venía» regresa la plantilla' do
      seller = AccessRole.for_account(account).find { |r| r.key == 'seller' }
      seller.update!(areas: seller.areas.merge('service' => 'all'))
      seller.restore!
      expect(seller.reload.area_level(:service)).to eq('none')
    end
  end

  describe 'casos' do
    let!(:my_sale)        { ticket(venta, agent) }
    let!(:other_sale)     { ticket(venta, other) }
    let!(:unassigned)     { ticket(venta, nil) }
    let!(:support_case)   { ticket(soporte, agent) }

    it 'el Supervisor (y el admin) ven todo' do
      expect(ids_for(agent)).to contain_exactly(my_sale.id, other_sale.id, unassigned.id, support_case.id)
      expect(ids_for(admin)).to contain_exactly(my_sale.id, other_sale.id, unassigned.id, support_case.id)
    end

    it 'el Vendedor ve solo sus oportunidades y las sin asignar, nada de Servicio' do
      give_role(agent, 'seller')
      expect(ids_for(agent)).to contain_exactly(my_sale.id, unassigned.id)

      get "#{base}/case_tickets/#{other_sale.id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'el Técnico no ve montos' do
      my_sale.update!(amount: 5000)
      give_role(agent, 'technician')
      expect(ids_for(agent)).to contain_exactly(support_case.id)

      AccessRole.for_account(account).find { |r| r.key == 'technician' }
                .update!(areas: AccessRole::DEFAULTS['technician']['areas'].merge('sales' => 'own'))
      get "#{base}/case_tickets/#{my_sale.id}", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['case_ticket']['amount']).to be_nil
    end

    it 'sin «reasignar» solo puede tomar para sí' do
      give_role(agent, 'seller')
      patch "#{base}/case_tickets/#{unassigned.id}/assign", params: { assignee_id: other.id },
                                                            headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)

      patch "#{base}/case_tickets/#{unassigned.id}/assign", params: { assignee_id: agent.id },
                                                            headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      expect(unassigned.reload.assignee_id).to eq(agent.id)
    end

    it 'Consulta no entra a los casos pero sí a los dashboards' do
      give_role(agent, 'viewer')
      get "#{base}/case_tickets", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)

      get "#{base}/case_tickets/metrics", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'conversaciones' do
    let(:inbox) { create(:inbox, account: account) }
    let!(:mine)   { create(:conversation, account: account, inbox: inbox, assignee: agent) }
    let!(:theirs) { create(:conversation, account: account, inbox: inbox, assignee: other) }

    before { create(:inbox_member, user: agent, inbox: inbox) }

    it 'con «solo lo suyo» la lista y la URL directa no muestran las de otros' do
      give_role(agent, 'seller')
      get "#{base}/conversations", params: { assignee_type: 'all' }, headers: agent.create_new_auth_token, as: :json
      ids = response.parsed_body['data']['payload'].pluck('id')
      expect(ids).to include(mine.display_id)
      expect(ids).not_to include(theirs.display_id)

      get "#{base}/conversations/#{theirs.display_id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'Consulta no entra a Conversaciones' do
      give_role(agent, 'viewer')
      get "#{base}/conversations", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'perfil' do
    it 'manda el rol, las áreas y las acciones al front' do
      give_role(agent, 'technician')
      get '/api/v1/profile', headers: agent.create_new_auth_token, as: :json
      access = response.parsed_body['accounts'].find { |a| a['id'] == account.id }['access']
      expect(access['role']).to eq('technician')
      expect(access['areas']['sales']).to eq('none')
      expect(access['actions']['see_amounts']).to be(false)
    end
  end
end
