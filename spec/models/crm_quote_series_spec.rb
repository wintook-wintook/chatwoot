# frozen_string_literal: true

require 'rails_helper'

# CrmZeus Q0 — serie de folios por agente (CTFOLIOS_USUARIOS).
RSpec.describe CrmQuoteSeries do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  it 'arma el folio como F_Folio de CRMZeus: serie + consecutivo con ceros hasta 9 caracteres' do
    expect(described_class.folio('C', 125)).to eq('C00000125')
    expect(described_class.folio('LAU', 7)).to eq('LAU000007')
    expect(described_class.folio('ABCDEFGH', 12)).to eq('ABCDEFGH12')
    expect(account.crm_quote_series.create!(user: agent, series: ' sxl ', last_number: 1515).next_folio).to eq('SXL001516')
  end

  it 'una serie por agente, sin repetirse en la cuenta; solo letras y números; el agente es de la cuenta' do
    account.crm_quote_series.create!(user: agent, series: 'LAU')
    other = create(:user, account: account, role: :agent)

    expect(account.crm_quote_series.new(user: agent, series: 'OTRA').tap(&:validate).errors.attribute_names).to include(:user_id)
    expect(account.crm_quote_series.new(user: other, series: 'lau').tap(&:validate).errors.attribute_names).to include(:series)
    expect(account.crm_quote_series.new(user: other, series: 'A-1').tap(&:validate).errors.attribute_names).to include(:series)
    expect(account.crm_quote_series.new(user: create(:user), series: 'X').tap(&:validate).errors.attribute_names).to include(:user)
  end
end
