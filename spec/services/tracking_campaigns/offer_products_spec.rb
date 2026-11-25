# frozen_string_literal: true

require 'rails_helper'

# Campaña con IA · Ofrecer — productos del Catálogo con precio de promoción, vigencia, la cotización de la IA con el
# precio de promoción y los «Casos» de la promoción.
RSpec.describe TrackingCampaigns::OfferProducts do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:product) { account.catalog_items.create!(name: 'Mantenimiento preventivo', price: 2600, description: 'Limpieza y revisión') }
  let(:raw) do
    { 'kind' => 'offer', 'offer_goal' => 'relay', 'valid_until' => 5.days.from_now.to_date.iso8601,
      'products' => [{ 'catalog_item_id' => product.id, 'promo_price' => '1,800' }, { 'catalog_item_id' => 'x' }] }
  end

  def function(brief)
    answers = { 'purpose' => 'offer' }.merge(brief.slice('products', 'valid_until', 'offer_goal'))
    Motor2::Config.new(seller.reload, answers: answers).function
  end

  it 'guarda los productos con su precio de promoción y la vigencia; la campaña termina ese día' do
    brief = TrackingCampaigns::Motor2Brief.brief(raw)
    expect(brief['products']).to eq([{ 'catalog_item_id' => product.id, 'promo_price' => '1800.0' }])
    expect(brief['valid_until']).to eq(raw['valid_until'])

    saved = TrackingCampaigns::Motor2Form.new(account, admin, { name: 'Promo', brief: raw }).save[:campaign]
    expect(saved.ends_at.in_time_zone('America/Mexico_City').to_date.iso8601).to eq(raw['valid_until'])
  end

  it 'la IA sabe el precio normal y el de promoción; vencida, que ya terminó y sin precio de promoción' do
    brief = TrackingCampaigns::Motor2Brief.brief(raw)
    expect(function(brief).facts_block).to include('Mantenimiento preventivo: $2,600.00 MXN → precio de promoción $1,800.00 MXN',
                                                   'la promoción vale hasta')
    expect(function(brief).promo_price_for(product)).to eq(1800)

    expired = brief.merge('valid_until' => 2.days.ago.to_date.iso8601)
    expect(function(expired).facts_block).to include('LA PROMOCIÓN YA TERMINÓ')
    expect(function(expired).facts_block).not_to include('1,800')
    expect(function(expired).promo_price_for(product)).to be_nil
  end

  it 'el precio de promoción respeta «el precio ya incluye el impuesto» del producto' do
    sixteen = account.tax_rates.create!(name: 'IVA 16 %', percent: 16)
    product.update!(tax_rate: sixteen, price_includes_tax: true)
    expect(product.quote_unit_price(1160)).to eq(1000)
  end

  it 'los Casos de Ofrecer prueban la cotización con promoción y la promoción vencida' do
    seller.update!(settings: seller.settings.merge('quote' => { 'mode' => 'draft' })) if seller.respond_to?(:settings)
    answers = TrackingCampaigns::Motor2Brief.brief(raw).slice('products', 'valid_until').merge('purpose' => 'offer')
    cases = TrackingCampaigns::Motor2Cases.new(seller.reload, answers)
    keys = cases.list.pluck(:key)
    expect(keys).to include('expired')
    result = { reply: 'Ya terminó, el precio es $2,600', trace: { 'tools' => [] } }
    allow(Motor2::Probe).to receive(:new).and_return(instance_double(Motor2::Probe, call: result))
    expect(cases.run('expired')).to include(ok: true)
    allow(Motor2::Probe).to receive(:new).and_return(instance_double(Motor2::Probe, call: result.merge(reply: 'Te queda en $1,800')))
    expect(cases.run('expired')).to include(ok: false)
  end
end
