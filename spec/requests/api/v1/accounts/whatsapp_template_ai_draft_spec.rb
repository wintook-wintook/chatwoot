# frozen_string_literal: true

require 'rails_helper'

# «Crear con IA»: el endpoint devuelve el borrador (no guarda ni llama a Meta). Solo admin.
RSpec.describe 'WhatsApp template AI draft' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/whatsapp/templates/ai_draft" }

  before do
    account.enable_features!('whatsapp_templates')
    allow_any_instance_of(Whatsapp::TemplateDrafter).to receive(:call) # rubocop:disable RSpec/AnyInstance
      .and_return(draft: { name: 'ventas_seguimiento' }, reason: 'Seguimiento.', warnings: [])
  end

  it 'devuelve la propuesta sin crear plantillas' do
    expect do
      post url, params: { goal: 'dar seguimiento' }, headers: admin.create_new_auth_token, as: :json
    end.not_to change(WhatsappTemplate, :count)
    expect(response.parsed_body).to include('draft' => { 'name' => 'ventas_seguimiento' }, 'reason' => 'Seguimiento.')
  end

  it 'solo administradores' do
    post url, params: { goal: 'x' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
