# frozen_string_literal: true

require 'rails_helper'

# prospeccion V4 (docs/prospeccion_estudio.md §9 F3, §10 V4) — lista de no contactar.
RSpec.describe ContactTrackings::OptOut do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }

  describe '.call' do
    it 'marca la baja con su fuente y cancela los seguimientos activos del contacto' do
      active = create(:contact_tracking, account: account, inbox: inbox, contact: contact, status: 'scheduled')

      expect(described_class.call(contact, source: 'reply')).to be(true)
      expect(contact.reload).to be_opted_out
      expect(contact.opted_out_source).to eq('reply')
      expect(active.reload.status).to eq('cancelled')
    end

    it 'si ya estaba dado de baja no cambia nada' do
      described_class.call(contact, source: 'link')

      expect(described_class.call(contact.reload, source: 'reply')).to be(false)
      expect(contact.reload.opted_out_source).to eq('link')
    end

    it '.undo se la quita' do
      described_class.call(contact, source: 'agent')
      described_class.undo(contact)

      expect(contact.reload).not_to be_opted_out
    end
  end

  describe '.requested_in?' do
    it 'reconoce las formas de pedir la baja' do
      ['Dame de baja por favor', 'denme de baja', 'Ya no me escriban', 'no me vuelvan a contactar',
       'No quiero recibir más correos', 'Quítenme de su lista', 'borren mis datos', 'BAJA', 'stop.',
       'no me envíen más', 'No me escribas', 'no me contacte por favor', 'no me vuelvas a escribir'].each do |text|
        expect(described_class.requested_in?(text)).to be(true), text
      end
    end

    it 'no confunde un «no me interesa» ni frases que solo mencionan «baja»' do
      ['No me interesa', 'Vivo en Baja California', '¿Cuál es el precio más bajo?', 'Claro que me interesa',
       'No me escribieron los precios', 'no me contestaste ayer', 'No me mandaron la cotización'].each do |text|
        expect(described_class.requested_in?(text)).to be(false), text
      end
    end
  end

  it 'el token del enlace lleva al contacto y uno alterado no' do
    token = described_class.token(contact)

    expect(described_class.contact_for(token)).to eq(contact)
    expect(described_class.contact_for("#{token}x")).to be_nil
  end

  it 'una campaña no inscribe a quien pidió la baja' do
    template = create(:tracking_template, account: account, inbox_id: inbox.id)
    campaign = create(:tracking_campaign, account: account, inbox: inbox, tracking_template: template, mode: 'continuous',
                                          scheduled_for: 1.hour.ago, respect_working_hours: false)
    create(:user, account: account, role: :administrator)
    described_class.call(contact, source: 'link')

    entry = TrackingCampaigns::Enroll.new(campaign, contact.reload, source: 'automation').call

    expect(entry.reason).to eq('opted_out')
  end

  it 'el analizador: «no me escriban» da de baja y la IA no contesta' do
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    tracking = create(:contact_tracking, account: account, inbox: inbox, contact: contact, conversation: conversation,
                                         status: 'scheduled')
    message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                               sender: contact, content: 'Ya no me escriban, gracias')
    job = ContactTrackingResponseAnalyzerJob.new
    allow(job).to receive(:process_message_for_tracking)

    job.perform(message.id)

    expect(contact.reload).to be_opted_out
    expect(tracking.reload.status).to eq('cancelled')
    expect(job).not_to have_received(:process_message_for_tracking)
  end
end
