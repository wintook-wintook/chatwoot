# frozen_string_literal: true

require 'rails_helper'

# «Probar» y «Casos» de la campaña prueban con la campaña guardada: sus imágenes y archivos («Cuando muestre interés»,
# «Al confirmar») salen como con un contacto real.
RSpec.describe 'Motor2 campaigns › Probar con las imágenes de la campaña' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:campaign) do
    account.tracking_campaigns.create!(name: 'Expo', engine: '2', status: 'saved', tracking_template: seller, user: admin,
                                       brief: { 'kind' => 'invite', 'offer_what' => 'Expo' }, touches: { 'attempts' => 1 })
  end

  it 'le pasa la campaña guardada al chat de prueba' do
    probe = instance_double(Motor2::Probe, call: { reply: 'Hola', files: ['flyer'], previews: [] })
    allow(Motor2::Probe).to receive(:new).and_return(probe)
    post "/api/v1/accounts/#{account.id}/motor2_campaigns/test",
         params: { campaign_id: campaign.id, brief: { kind: 'invite' }, messages: [{ role: 'user', content: 'Sí, mándame la información' }] },
         headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(Motor2::Probe).to have_received(:new).with(anything, hash_including(campaign: campaign))
  end
end
