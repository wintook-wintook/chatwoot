# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — Fase 1 (docs/campanas_agentes_ia_capacidad_plan.md §13)
RSpec.describe TrackingDelivery do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:tracking) { create(:contact_tracking, account: account, inbox: inbox) }
  let(:delivery) do
    described_class.create!(account: account, contact_tracking: tracking, kind: 'template', attempt_number: 1,
                            status: 'sent', sent_at: 1.minute.ago)
  end

  describe '#apply_message_status!' do
    it 'avanza sent → delivered → read y guarda cuándo' do
      expect(delivery.apply_message_status!('delivered')).to be(true)
      expect(delivery.apply_message_status!('read')).to be(true)

      expect(delivery).to have_attributes(status: 'read', delivered_at: be_present, read_at: be_present)
    end

    it 'un estado viejo no pisa a uno nuevo (Meta manda read antes que delivered)' do
      delivery.apply_message_status!('read')

      expect(delivery.apply_message_status!('delivered')).to be(false)
      expect(delivery.status).to eq('read')
      expect(delivery.delivered_at).to be_present
    end

    it 'failed guarda el código, el detalle y el tipo de error' do
      delivery.apply_message_status!('failed', '131049: This message was not delivered to maintain healthy ecosystem engagement.')

      expect(delivery).to have_attributes(status: 'failed', error_code: '131049', error_kind: 'marketing',
                                          failed_at: be_present)
      expect(delivery.error_summary).to start_with('Meta 131049: This message was not delivered')
    end

    it 'un failed tardío no deshace una entrega confirmada' do
      delivery.apply_message_status!('delivered')

      expect(delivery.apply_message_status!('failed', '131000: Something went wrong')).to be(false)
      expect(delivery.status).to eq('delivered')
    end

    it 'una entrega que llega después de "sin confirmar" sí se registra' do
      delivery.update!(status: 'unconfirmed')

      expect(delivery.apply_message_status!('delivered')).to be(true)
    end
  end

  describe '.parse_error' do
    it 'entiende el cuerpo JSON del rechazo al momento' do
      raw = { error: { message: '(#100) Invalid parameter', code: 100, error_data: { details: 'Param text cannot have new-line' } } }.to_json

      expect(described_class.parse_error(raw)).to eq(code: '100', title: 'Param text cannot have new-line')
    end

    it 'entiende "código: título" del webhook' do
      expect(described_class.parse_error('131026: Message undeliverable')).to eq(code: '131026', title: 'Message undeliverable')
    end

    it 'sin código conserva el texto' do
      expect(described_class.parse_error('boom')).to eq(code: nil, title: 'boom')
    end
  end

  describe TrackingDeliveries::ErrorClassifier do
    it 'clasifica los códigos de Meta' do
      expect(%w[130429 131049 131026 132001 131042 190 999].map { |code| described_class.kind(code) })
        .to eq(%w[temporary marketing permanent config config config permanent])
      expect(described_class.unreachable?('131026')).to be(true)
    end
  end
end
