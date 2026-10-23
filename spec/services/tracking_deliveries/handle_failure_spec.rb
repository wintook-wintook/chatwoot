# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — Fase 1 (docs/campanas_agentes_ia_capacidad_plan.md §13)
RSpec.describe TrackingDeliveries::HandleFailure do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:campaign) { create(:tracking_campaign, account: account, inbox: inbox, scheduled_for: 1.hour.ago) }
  # Ya mandó el intento 1 y quedó programado el 2 (así lo deja ContactTrackingJob).
  let(:tracking) do
    create(:contact_tracking, account: account, inbox: inbox, contact: contact, conversation_id: conversation.id,
                              tracking_campaign: campaign, attempt_count: 1, status: 'scheduled', scheduled_for: 1.day.from_now)
  end

  def failed_delivery(code, retry_count: 0, sent_at: 10.minutes.ago)
    TrackingDelivery.create!(account: account, contact_tracking: tracking, tracking_campaign: campaign, kind: 'template',
                             attempt_number: 1, retry_count: retry_count, status: 'failed', sent_at: sent_at,
                             failed_at: Time.current, **TrackingDelivery.error_attributes("#{code}: error de prueba"))
  end

  def handle(delivery, **options)
    described_class.new(delivery, tracking: tracking, **options).perform
  end

  describe 'error temporal por webhook' do
    it 'regresa el seguimiento al intento que falló y lo reprograma a 5 minutos' do
      delivery = failed_delivery('130429')

      expect(handle(delivery)).to eq(:retry)
      expect(tracking.reload).to have_attributes(status: 'scheduled', attempt_count: 0)
      expect(tracking.scheduled_for).to be_within(5.seconds).of(5.minutes.from_now)
      expect(tracking.last_error).to include('Meta 130429', 'reintento 1/3')
      expect(delivery.reload.next_retry_at).to be_present
    end

    it 'el tercer reintento espera 2 horas y después ya no se reintenta' do
      expect(handle(failed_delivery('131000', retry_count: 2))).to eq(:retry)
      expect(tracking.reload.scheduled_for).to be_within(5.seconds).of(2.hours.from_now)

      expect(handle(failed_delivery('131000', retry_count: 3))).to eq(:permanent)
    end

    it 'no reintenta si el contacto ya respondió después del envío' do
      delivery = failed_delivery('130429')
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'hola')

      expect(handle(delivery)).to eq(:permanent)
      expect(tracking.reload.attempt_count).to eq(1)
    end

    it 'no reintenta si ya hay un envío más nuevo del seguimiento' do
      delivery = failed_delivery('130429')
      TrackingDelivery.create!(account: account, contact_tracking: tracking, kind: 'template', attempt_number: 2, status: 'sent')

      expect(handle(delivery)).to eq(:permanent)
    end

    it 'el límite de marketing (131049) se reintenta una sola vez, a las 24 h' do
      expect(handle(failed_delivery('131049'))).to eq(:retry)
      expect(tracking.reload.scheduled_for).to be_within(5.seconds).of(24.hours.from_now)

      expect(handle(failed_delivery('131049', retry_count: 1))).to eq(:permanent)
    end
  end

  describe 'error de configuración' do
    it 'pausa la campaña con el motivo y el seguimiento, listo para reenviar el intento al reanudar' do
      delivery = failed_delivery('132001')

      expect(handle(delivery)).to eq(:config)
      expect(campaign.reload).to have_attributes(status: 'paused', paused_reason: 'Meta 132001: error de prueba')
      expect(tracking.reload).to have_attributes(status: 'paused', paused_by_campaign: true, attempt_count: 0)
    end

    it 'sin campaña, pausa solo el seguimiento' do
      tracking.update!(tracking_campaign: nil)
      delivery = failed_delivery('131042')
      delivery.update!(tracking_campaign: nil)

      expect(handle(delivery)).to eq(:config)
      expect(tracking.reload).to have_attributes(status: 'paused', paused_by_campaign: false)
    end
  end

  describe 'error permanente' do
    it 'contacto inalcanzable (131026): el seguimiento queda fallido' do
      expect(handle(failed_delivery('131026'))).to eq(:unreachable)
      expect(tracking.reload).to have_attributes(status: 'failed', last_error: 'Meta 131026: error de prueba')
    end

    it 'otro permanente: el seguimiento sigue su curso con el motivo a la vista' do
      expect(handle(failed_delivery('131047'))).to eq(:permanent)
      expect(tracking.reload).to have_attributes(status: 'scheduled', attempt_count: 1, last_error: 'Meta 131047: error de prueba')
    end
  end

  describe 'rechazo al momento (desde ContactTrackingJob)' do
    it 'reprograma aunque el seguimiento esté activo; attempt_count no se movió' do
      tracking.update!(status: 'active', attempt_count: 0)
      delivery = failed_delivery('130429')

      expect(handle(delivery, immediate: true)).to eq(:retry)
      expect(tracking.reload).to have_attributes(status: 'scheduled', attempt_count: 0)
    end
  end
end
