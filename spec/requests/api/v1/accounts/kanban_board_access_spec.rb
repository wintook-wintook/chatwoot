# frozen_string_literal: true

require 'rails_helper'

# Embudo de contactos — el tablero muestra las mismas conversaciones que Conversaciones:
# solo de sus bandejas y, con «Solo lo suyo», solo las suyas.
RSpec.describe 'Tablero de conversaciones (quién ve qué)' do
  let(:account) { create(:account) }
  let(:seller) { create(:user, account: account, role: :agent) }
  let(:other) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:board) { create(:kanban_type_process, account: account) }
  let!(:column) { create(:kanban_process, kanban_type_process: board, position: 0, default: true) }
  let(:url) { "/api/v1/accounts/#{account.id}/conversations/kanban/filter_by_both_kanban" }

  def card(assignee, box = inbox)
    create(:conversation, account: account, inbox: box, assignee: assignee)
      .tap { |c| c.update!(kanban_type_process_id: board.id, kanban_process_id: column.id) }
  end

  def ids_for(user)
    get url, params: { kanban_type_process_id: board.id, kanban_process_id: column.id }, headers: user.create_new_auth_token
    expect(response).to have_http_status(:success)
    response.parsed_body['data'].pluck('id')
  end

  before do
    create(:inbox_member, user: seller, inbox: inbox)
    create(:inbox_member, user: other, inbox: inbox)
  end

  it 'con «Solo lo suyo» ve solo sus tarjetas' do
    role = AccessRole.for_account(account).find { |r| r.key == 'seller' }
    account.account_users.find_by(user: seller).update!(access_role: role)
    mine = card(seller)
    card(other)

    expect(ids_for(seller)).to contain_exactly(mine.display_id)
  end

  it 'no ve tarjetas de bandejas que no son suyas' do
    visible = card(other)
    card(other, create(:inbox, account: account))

    expect(ids_for(seller)).to contain_exactly(visible.display_id)
  end
end
