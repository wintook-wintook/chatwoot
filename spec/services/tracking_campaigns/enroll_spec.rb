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
  end

  # proyecto@automatizacion_campanas — Fase 2: la conversación se abre al enviar, no al inscribir.
  it 'sin conversación en el inbox no abre una al inscribir: la abre el envío, asignada y con nota' do
    tracking = enroll.contact_tracking
    expect(tracking.conversation_id).to be_nil
    expect(contact.conversations.where(inbox_id: inbox.id)).to be_empty

    conversation = ContactTrackingJob.new.send(:find_or_create_conversation, tracking)

    expect(conversation.inbox_id).to eq(inbox.id)
    expect(conversation.assignee).to be_present
    expect(conversation.messages.where(private: true).last.content).to eq(%(📋 Seguimiento de la campaña "#{campaign.name}"))
  end

  # prospeccion F1 — el asunto de la campaña viaja a la conversación que abre el agente.
  describe 'asunto del correo' do
    let(:inbox) { create(:channel_email, account: account).inbox }
    let(:contact) { create(:contact, account: account, name: 'Juan Pérez', email: 'juan@example.com') }

    def open_for(tracking)
      ContactTrackingJob.new.send(:find_or_create_conversation, tracking)
    end

    it 'en una bandeja de correo, la conversación nueva lleva el asunto armado' do
      campaign.update!(email_subject: '{{contacto}}, una idea para tus envíos')

      conversation = open_for(enroll.contact_tracking)

      expect(conversation.additional_attributes['mail_subject']).to eq('Juan, una idea para tus envíos')
    end

    it 'si el contacto ya tenía hilo, se conserva el asunto del hilo' do
      campaign.update!(email_subject: 'Asunto nuevo')
      thread = create(:conversation, account: account, inbox: inbox, contact: contact,
                                     additional_attributes: { 'mail_subject' => 'Demostracion' })

      expect(open_for(enroll.contact_tracking)).to eq(thread)
      expect(thread.reload.additional_attributes['mail_subject']).to eq('Demostracion')
    end

    it 'sin asunto en la campaña, la conversación queda como antes' do
      expect(open_for(enroll.contact_tracking).additional_attributes['mail_subject']).to be_nil
    end
  end

  it 'fuera de correo, el asunto de la campaña no se usa' do
    campaign.update!(email_subject: 'No aplica')

    conversation = ContactTrackingJob.new.send(:find_or_create_conversation, enroll.contact_tracking)

    expect(conversation.additional_attributes['mail_subject']).to be_nil
  end

  # prospeccion V3 — por lote, el tope diario reparte en días hábiles en vez de omitir.
  describe 'tope diario' do
    let(:inbox) { create(:inbox, account: account, timezone: 'America/Mexico_City', working_hours_enabled: false) }
    let(:monday_noon) { ActiveSupport::TimeZone['America/Mexico_City'].local(2026, 10, 5, 12, 0) }

    it 'por lote reparte: 2 por día, el 3.º y el 4.º salen el siguiente día hábil' do
      campaign.update!(mode: 'batch', purpose: 'prospecting', daily_cap: 2, scheduled_for: monday_noon - 1.hour)
      entries = travel_to(monday_noon) do
        create_list(:contact, 4, account: account, phone_number: nil).map.with_index do |c, i|
          c.update!(phone_number: "+52155500000#{i}")
          described_class.new(campaign, c, source: 'batch', at: monday_noon).call
        end
      end

      expect(entries).to all(be_enrolled)
      days = entries.map { |e| e.contact_tracking.scheduled_for.in_time_zone('America/Mexico_City').to_date.day }
      expect(days).to eq([5, 5, 6, 6])
    end

    it 'en continua, el que pasa del tope del día sigue omitido' do
      campaign.update!(daily_cap: 1)
      enroll

      expect(enroll(create(:contact, account: account)).reason).to eq('daily_cap')
    end
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

    # prospeccion V7a
    it 'correo inválido en una bandeja de correo, aunque ya tenga conversación' do
      allow(campaign.inbox).to receive(:channel_type).and_return('Channel::Email')
      allow(ContactTrackings::EmailCheck).to receive(:lookup).and_return(false)
      contact.update!(email: 'juan@dominio-muerto.mx')
      create(:conversation, account: account, inbox: inbox, contact: contact)

      expect(enroll.reason).to eq('invalid_email')
      expect(ContactTracking.count).to eq(0)
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

  describe 'intentos: los que define el Agente IA' do
    it 'uno por plantilla WhatsApp' do
      template.update!(whatsapp_templates: %w[uno dos])
      expect(enroll.contact_tracking.max_attempts).to eq(2)

      template.update!(whatsapp_templates: %w[uno dos tres cuatro])
      expect(enroll(create(:contact, account: account)).contact_tracking.max_attempts).to eq(4)
    end

    it 'sin plantillas WhatsApp, 3 mensajes con IA' do
      template.update!(whatsapp_templates: [])
      expect(enroll.contact_tracking.max_attempts).to eq(3)
    end

    it 'el seguimiento nace válido (antes 2 plantillas para 3 intentos no pasaba la validación)' do
      template.update!(whatsapp_templates: %w[uno dos])
      expect(enroll.contact_tracking).to be_valid
    end
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
