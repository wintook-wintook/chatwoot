# frozen_string_literal: true

require 'rails_helper'

# prospeccion V5 (docs/prospeccion_estudio.md §8.1, §10.3 V5) — en qué va cada prospecto.
RSpec.describe TrackingCampaigns::ProspectClassifier do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, timezone: 'America/Mexico_City') }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }
  let(:campaign) do
    create(:tracking_campaign, account: account, inbox: inbox, tracking_template: template, purpose: 'prospecting', daily_cap: 30)
  end
  let(:tracking) do
    create(:contact_tracking, account: account, inbox: inbox, contact: contact, conversation: conversation,
                              tracking_campaign: campaign, status: 'scheduled', max_attempts: 3, attempt_count: 1)
  end
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                     sender: contact, content: 'texto del prospecto')
  end

  before { create(:integrations_hook, account: account, app_id: 'openai', settings: { 'api_key' => 'sk-test' }) }

  def openai_says(*labels)
    responses = labels.map do |label|
      content = label.nil? ? 'no json' : { categoria: label }.to_json
      { status: 200, body: { choices: [{ message: { content: content } }] }.to_json }
    end
    stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_return(*responses)
  end

  it 'interesado: etapa «interesado» y cuenta en el embudo (interested_at)' do
    openai_says('interested')

    expect(described_class.call(tracking, message)).to eq('interested')
    expect(tracking.reload).to have_attributes(prospect_stage: 'interested', prospect_exit: nil)
    expect(tracking.interested_at).to be_present
  end

  it 'no ahora: un solo toque más, a los 30 días y nunca en fin de semana' do
    openai_says('not_now')
    described_class.call(tracking, message)

    tracking.reload
    expect(tracking).to have_attributes(prospect_exit: 'not_now', prospect_stage: 'replied', max_attempts: 2)
    expect(tracking.scheduled_for).to be > 29.days.from_now
    expect(tracking.scheduled_for.in_time_zone('America/Mexico_City')).not_to(satisfy { |t| t.saturday? || t.sunday? })
  end

  it 'no le interesa / no es la persona: se cierra sin más toques' do
    openai_says('not_interested')
    described_class.call(tracking, message)

    expect(tracking.reload).to have_attributes(prospect_exit: 'not_interested', status: 'completed')
  end

  it 'la etapa nunca baja: un interesado que luego saluda sigue interesado' do
    tracking.update!(prospect_stage: 'interested')
    openai_says('other')
    described_class.call(tracking, message)

    expect(tracking.reload.prospect_stage).to eq('interested')
  end

  it 'si gpt-4o-mini no responde bien, pregunta a gpt-4o' do
    openai_says(nil, 'wrong_person')

    expect(described_class.call(tracking, message)).to eq('wrong_person')
    expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/chat/completions').twice
  end

  it 'si OpenAI falla, queda «respondió» y no rompe el turno' do
    stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_timeout

    expect(described_class.call(tracking, message)).to eq('other')
    expect(tracking.reload.prospect_stage).to eq('replied')
  end

  it 'en campañas de seguimiento no clasifica' do
    campaign.update!(purpose: 'follow_up')

    expect(described_class.call(tracking, message)).to be_nil
    expect(tracking.reload.prospect_stage).to be_nil
  end

  it 'la baja (V4) marca la salida «baja»' do
    tracking
    ContactTrackings::OptOut.call(contact, source: 'reply')

    expect(tracking.reload).to have_attributes(prospect_exit: 'opted_out', status: 'cancelled')
  end
end
