# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F2) — los permisos que marca el super admin
RSpec.describe User do
  let(:user) { create(:user) }

  it 'sin marcar no ve ni gestiona' do
    expect(user.can_view_licenses?).to be(false)
    expect(user.can_manage_licenses?).to be(false)
  end

  it 'gestionar incluye ver' do
    user.update!(can_manage_licenses: '1')

    expect(user.reload.can_view_licenses?).to be(true)
  end

  it 'ver no da gestionar, y no pisa otros atributos' do
    user.update!(custom_attributes: { 'can_publish_prompts' => true })
    user.update!(can_view_licenses: true)

    expect(user.reload).to have_attributes(can_view_licenses?: true, can_manage_licenses?: false, can_publish_prompts?: true)
  end
end
