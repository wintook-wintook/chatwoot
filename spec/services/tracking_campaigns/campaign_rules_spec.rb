# frozen_string_literal: true

require 'rails_helper'

# §10.12 (U1, D21) — reglas de una campaña, por canal.
RSpec.describe TrackingCampaigns::CampaignRules do
  let(:account) { create(:account) }
  let(:email_inbox) { create(:channel_email, account: account).inbox }
  let(:other_inbox) { create(:inbox, account: account) }

  def error(**overrides)
    described_class.error_for(**{ daily_cap: 30, email_subject: 'Hola', inbox: email_inbox }.merge(overrides))
  end

  it 'en correo pide tope diario de 1 a 500' do
    expect(error(daily_cap: nil)).to include('tope diario es obligatorio')
    expect(error(daily_cap: 0)).to include('va de 1 a 500')
    expect(error(daily_cap: 501)).to include('va de 1 a 500')
    expect(error(daily_cap: 30)).to be_nil
  end

  it 'en correo pide asunto' do
    expect(error(email_subject: ' ')).to include('asunto es obligatorio')
  end

  it 'en otros canales el tope es opcional, pero si viene va de 1 a 500; sin asunto' do
    expect(error(inbox: other_inbox, daily_cap: nil, email_subject: nil)).to be_nil
    expect(error(inbox: other_inbox, daily_cap: 501)).to include('va de 1 a 500')
  end
end
