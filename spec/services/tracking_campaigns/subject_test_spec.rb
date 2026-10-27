# frozen_string_literal: true

require 'rails_helper'

# prospeccion P3 (docs/prospeccion_estudio.md §10.10) — prueba A/B de asuntos.
RSpec.describe TrackingCampaigns::SubjectTest do
  let(:account) { create(:account) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }
  let(:campaign) do
    create(:tracking_campaign, account: account, inbox: inbox, tracking_template: template, purpose: 'prospecting', daily_cap: 30,
                               user: create(:user, account: account), email_subject: '{{contacto}}, una idea',
                               email_subject_b: '¿{{contacto}}, tienes 5 minutos?')
  end

  def tracking_for(contact, attrs = {})
    create(:contact_tracking, { account: account, inbox: inbox, contact: contact, tracking_campaign: campaign,
                                status: 'pending' }.merge(attrs))
  end

  it 'reparte A, B, A, B… y anota el asunto en el seguimiento al abrir la conversación' do
    subjects = Array.new(4) do |n|
      contact = create(:contact, account: account, name: "Juan#{n} Pérez", email: "juan#{n}@empresa.mx")
      tracking = tracking_for(contact)
      conversation = TrackingCampaigns::TrackingBuilder.new(campaign, contact).open_conversation(tracking: tracking)
      [tracking.reload.subject_variant, conversation.additional_attributes['mail_subject']]
    end

    expect(subjects.map(&:first)).to eq(%w[a b a b])
    expect(subjects.first.last).to eq('Juan0, una idea')
    expect(subjects.second.last).to eq('¿Juan1, tienes 5 minutos?')
  end

  it 'sin asunto B no hay prueba: todos reciben A y no se anota nada' do
    campaign.update!(email_subject_b: nil)

    expect(described_class.pick(campaign)).to eq(['{{contacto}}, una idea', nil])
    expect(described_class.stats(campaign)).to be_nil
  end

  it 'con ganador: todos reciben el ganador y la comparación ya no cambia' do
    described_class.choose!(campaign, 'b')

    expect(described_class.pick(campaign)).to eq(['¿{{contacto}}, tienes 5 minutos?', nil])
    expect(described_class.stats(campaign)[:winner]).to eq('b')
  end

  it 'en cualquier campaña con asunto B hay prueba (§10.12)' do
    campaign.update!(purpose: 'follow_up')

    expect(described_class.pick(campaign).last).to eq('a')
  end

  describe 'la comparación' do
    def seed(variant, contacted, replied)
      contacted.times do |n|
        tracking_for(create(:contact, account: account), subject_variant: variant, attempt_count: 1,
                                                         prospect_stage: n < replied ? 'replied' : nil)
      end
    end

    it 'cuenta contactados, respondieron y su tasa por asunto' do
      seed('a', 4, 1)
      seed('b', 4, 2)

      rows = described_class.stats(campaign)[:variants]
      expect(rows['a']).to include(contacted: 4, replied: 1, rate: 25.0)
      expect(rows['b']).to include(contacted: 4, replied: 2, rate: 50.0, subject: '¿{{contacto}}, tienes 5 minutos?')
    end

    it 'con pocos datos no señala a ninguno; con 20 en cada uno, al que va ganando' do
      seed('a', 4, 1)
      seed('b', 4, 2)
      expect(described_class.stats(campaign)[:leader]).to be_nil

      seed('a', 16, 2)
      seed('b', 16, 6)
      expect(described_class.stats(campaign)[:leader]).to eq('b')
    end
  end

  it 'solo se puede elegir A o B' do
    expect(described_class.choose!(campaign, 'c')).to be(false)
    expect(campaign.reload.subject_ab_winner).to be_nil
  end
end
