# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — F1 (docs/automatizacion_campanas_plan.md §4.1)
RSpec.describe TrackingCampaigns::Enroll do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }
  let(:campaign) do
    create(:tracking_campaign, account: account, inbox: inbox, tracking_template: template, mode: 'continuous',
                               scheduled_for: 1.hour.ago, respect_working_hours: false)
  end
  let(:contact) { create(:contact, account: account) }
  let(:rule) { create(:automation_rule, account: account, name: 'Demo') }

  # La conversación nueva se asigna a un agente de la cuenta (como el lote de siempre).
  before { create(:user, account: account, role: :administrator) }

  def enroll(who = contact, **options)
    described_class.new(campaign, who, source: 'automation', automation_rule: rule, **options).call
  end

  it 'inscribe: crea el seguimiento de la campaña, programado a su hora, y lo liga a la inscripción' do
    entry = enroll

    expect(entry).to be_enrolled
    tracking = entry.contact_tracking
    expect(tracking).to have_attributes(tracking_campaign_id: campaign.id, inbox_id: inbox.id, contact_id: contact.id,
                                        tracking_template_id: template.id, status: 'pending')
    expect(tracking.scheduled_for).to be_within(1.second).of(Time.current)
    expect(tracking.conversation.messages.where(private: true).last.content)
      .to eq(%(📋 Inscrito en la campaña "#{campaign.name}" por la automatización "Demo"))
  end

  it 'reusa la conversación que el contacto ya tiene en el inbox de la campaña' do
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)

    expect(enroll.contact_tracking.conversation_id).to eq(conversation.id)
  end

  describe 'omitidos, con su motivo' do
    it 'campaña pausada, terminada o pasada la ventana' do
      campaign.update!(status: 'paused')
      expect(enroll.reason).to eq('campaign_closed')

      campaign.update!(status: 'running', ends_at: 1.minute.ago)
      expect(enroll(create(:contact, account: account)).reason).to eq('campaign_closed')
    end

    it 'ya inscrito: el contacto entra una sola vez' do
      enroll
      second = enroll

      expect(second.reason).to eq('already_enrolled')
      expect(ContactTracking.where(tracking_campaign_id: campaign.id).count).to eq(1)
    end

    it 'con un Agente IA activo en el inbox de la campaña' do
      create(:contact_tracking, account: account, contact: contact, inbox: inbox, status: 'active')

      expect(enroll.reason).to eq('active_tracking')
    end

    it 'el canal no lo puede contactar (sin teléfono en WhatsApp)' do
      allow(campaign.inbox).to receive(:channel_type).and_return('Channel::Whatsapp')
      contact.update!(phone_number: nil)

      expect(enroll.reason).to eq('not_contactable')
    end

    it 'el tope del día' do
      campaign.update!(daily_cap: 1)
      enroll

      expect(enroll(create(:contact, account: account)).reason).to eq('daily_cap')
    end

    it 'la hora calculada cae después del fin' do
      campaign.update!(ends_at: 30.minutes.from_now, entry_delay_minutes: 60)

      expect(enroll.reason).to eq('outside_window')
    end
  end

  it 'antes del inicio se inscribe igual, programado para el inicio' do
    start = 2.days.from_now.change(usec: 0)
    campaign.update!(scheduled_for: start, status: 'draft')

    expect(enroll.contact_tracking.scheduled_for).to eq(start)
  end

  it 'si otra inscripción ganó la carrera, queda "ya inscrito" sin crear otro seguimiento' do
    service = described_class.new(campaign, contact, source: 'automation')
    allow(service).to receive(:skip_reason).and_return(nil)
    create(:tracking_campaign_entry, tracking_campaign: campaign, contact: contact)

    expect(service.call.reason).to eq('already_enrolled')
    expect(ContactTracking.where(tracking_campaign_id: campaign.id)).to be_empty
  end

  it 'si crear el seguimiento falla, deshace la inscripción y el error sube' do
    allow(ContactTracking).to receive(:insert!).and_raise(ActiveRecord::StatementInvalid, 'boom')

    expect { enroll }.to raise_error(ActiveRecord::StatementInvalid)
    expect(campaign.entries.enrolled).to be_empty
  end

  it 'el lote pasa por el mismo camino' do
    service = ContactTrackings::BulkAssignService.new(
      account: account, current_user: create(:user, account: account), filter_payload: [], template_id: template.id,
      scheduled_for: 1.hour.from_now, campaign_name: 'Lote', campaign: campaign
    )
    allow(service).to receive(:resolve_contacts).and_return(Contact.where(id: [contact.id, create(:contact, account: account).id]))
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, status: 'active')

    expect(service.process!).to include(inserted: 1, skipped: 1, errors: [])
    expect(campaign.entries.pluck(:source).uniq).to eq(['batch'])
  end
end
