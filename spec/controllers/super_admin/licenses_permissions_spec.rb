# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F2) — las casillas del super admin
RSpec.describe 'Super admin: permisos de licencias', type: :request do
  let(:super_admin) { create(:super_admin) }

  it 'marca «Ver» y «Gestionar licencias» en un usuario' do
    user = create(:user)
    sign_in(super_admin, scope: :super_admin)

    patch "/super_admin/users/#{user.id}", params: { user: { name: user.name, can_view_licenses: '1', can_manage_licenses: '1' } }

    expect(user.reload).to have_attributes(can_view_licenses?: true, can_manage_licenses?: true)
  end

  it 'marca una cuenta como «Cuenta de Wintook»' do
    account = create(:account)
    sign_in(super_admin, scope: :super_admin)

    patch "/super_admin/accounts/#{account.id}", params: { account: { name: account.name, wintook_internal: '1' } }

    expect(account.reload.wintook_internal?).to be(true)
  end
end
