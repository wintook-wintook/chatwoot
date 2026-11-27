# frozen_string_literal: true

require 'rails_helper'

# Campaña con IA — las imágenes: en correo, las de «cuando muestre interés» van con el primer correo; la revisión
# avisa de las que nunca se mandarían.
RSpec.describe TrackingCampaigns::Motor2FileCheck do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }

  def campaign(kind, inbox)
    account.tracking_campaigns.create!(name: 'Promo', engine: '2', status: 'running', tracking_template: seller, inbox: inbox, user: admin,
                                       scheduled_for: 1.day.ago, brief: { 'kind' => kind, 'offer_what' => 'Promo' }, touches: { 'attempts' => 2 })
  end

  def file(camp, name, rules)
    AiAgentAttachment.create!(account: account, tracking_campaign: camp, name: name, rules: rules,
                              file: fixture_file_upload(Rails.root.join('spec/assets/sample.png'), 'image/png'))
  end

  it 'en correo, la de interés va adjunta al primer correo (y solo ahí)' do
    camp = campaign('offer', create(:channel_email, account: account).inbox)
    file(camp, 'foto', { 'interest' => true })
    tracking = ContactTracking.new(account: account, tracking_campaign: camp, inbox: camp.inbox, tracking_template: seller)
    expect(ContactTrackings::AttemptFiles.campaign_names(tracking, 1)).to eq(['foto'])
    expect(ContactTrackings::AttemptFiles.campaign_names(tracking, 2)).to eq([])
  end

  it 'avisa de las que nunca se mandan o cuyo momento no aplica' do
    wa = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox
    camp = campaign('survey', wa)
    file(camp, 'sin-regla', { 'interest' => false })
    file(camp, 'interes', { 'interest' => true })
    file(camp, 'pedida', { 'ask' => true })
    texts = described_class.new(camp).call.pluck(:text)
    expect(texts.join("\n")).to include('«sin-regla»: no tiene cuándo va', '«interes»: en una encuesta')
    expect(texts.join).not_to include('pedida')
  end

  it 'en Invitar, «cuando muestre interés» también aplica (sale con la información del evento)' do
    wa = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox
    camp = campaign('invite', wa)
    file(camp, 'flyer', { 'interest' => true })
    expect(described_class.new(camp).call).to be_empty
  end

  it '«cuando lo logra» en Ofrecer: sí con cita o palabra clave; con «pasa a quien sigue», avisa' do
    wa = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox
    camp = campaign('offer', wa)
    camp.update!(brief: camp.brief.merge('offer_goal' => 'appointment'))
    file(camp, 'mapa', { 'confirm' => true })
    expect(described_class.new(camp).call).to be_empty

    camp.update!(brief: camp.brief.merge('offer_goal' => 'relay'))
    expect(described_class.new(camp).call.pluck(:text).join).to include('«mapa»: con «le interesa → pasa a quien sigue»')
  end
end
