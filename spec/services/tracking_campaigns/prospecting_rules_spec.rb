# frozen_string_literal: true

require 'rails_helper'

# prospeccion V3 (docs/prospeccion_estudio.md §10.2) — reglas de una campaña de prospección.
RSpec.describe TrackingCampaigns::ProspectingRules do
  let(:account) { create(:account) }
  let(:email_inbox) { create(:channel_email, account: account).inbox }
  let(:other_inbox) { create(:inbox, account: account) }

  def error(**overrides)
    described_class.error_for(**{ purpose: 'prospecting', daily_cap: 30, email_subject: 'Hola', inbox: email_inbox }.merge(overrides))
  end

  it 'seguimiento no tiene reglas extra' do
    expect(error(purpose: 'follow_up', daily_cap: nil, email_subject: nil)).to be_nil
  end

  it 'pide tope diario de 1 a 500' do
    expect(error(daily_cap: nil)).to include('tope diario es obligatorio')
    expect(error(daily_cap: 0)).to include('va de 1 a 500')
    expect(error(daily_cap: 501)).to include('va de 1 a 500')
    expect(error(daily_cap: 30)).to be_nil
  end

  it 'en correo pide asunto; en otros canales no' do
    expect(error(email_subject: ' ')).to include('asunto es obligatorio')
    expect(error(email_subject: nil, inbox: other_inbox)).to be_nil
  end
end
