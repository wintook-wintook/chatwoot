# frozen_string_literal: true

require 'rails_helper'

# «A quién»: la audiencia clasificada por páginas, con filtro por grupo, búsqueda, los ids para quitar a todos y el CSV.
RSpec.describe TrackingCampaigns::AudiencePage do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let!(:contacts) do
    Array.new(5) { |i|
      create(:contact, account: account, name: "Cliente #{i}", email: "c#{i}@ejemplo.com",
                       additional_attributes: { 'company_name' => "Empresa #{i}" })
    } +
      [create(:contact, account: account, name: 'Sin correo', email: nil)]
  end
  let(:payload) do
    [{ 'attribute_key' => 'name', 'filter_operator' => 'contains', 'values' => ['i'], 'query_operator' => nil, 'attribute_model' => 'standard' }]
  end

  def page(extra = {})
    described_class.new(account, admin, { payload: payload, inbox_id: inbox.id, per_page: 10 }.merge(extra)).call
  end

  it 'cuenta todo y regresa la página pedida' do
    result = page(per_page: 10, excluded_contact_ids: [contacts[0].id])
    expect(result[:counts]).to include(ready: 4, unreachable: 1, excluded: 1, total: 6)
    expect(result[:matching]).to eq(6)
    expect(result[:contacts].size).to eq(6)
    expect(result[:contacts].first).to include(:company)

    second = page(per_page: 10, page: 2)
    expect(second[:contacts]).to eq([])
  end

  it 'filtra por grupo y por búsqueda, y da los ids de todo lo filtrado' do
    expect(page(bucket: 'unreachable')[:contacts].pluck(:name)).to eq(['Sin correo'])
    expect(page(q: 'empresa 3')[:contacts].pluck(:name)).to eq(['Cliente 3'])
    expect(page(bucket: 'ready', ids: 1)[:ids]).to match_array(contacts.first(5).map(&:id))
  end

  it 'el CSV trae lo filtrado' do
    csv = described_class.new(account, admin, { payload: payload, inbox_id: inbox.id, q: 'Cliente 1' }).csv
    expect(csv.lines.first).to start_with('Nombre,Empresa')
    expect(csv).to include('Cliente 1,Empresa 1', 'Sí')
  end
end
