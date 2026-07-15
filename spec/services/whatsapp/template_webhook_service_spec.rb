# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — webhook de ciclo de vida de plantilla.
RSpec.describe Whatsapp::TemplateWebhookService do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let!(:template) do
    create(:whatsapp_template, account: channel.account, channel_whatsapp: channel,
                               meta_template_id: '555', status: 'PENDING')
  end

  def change(field, value)
    { 'field' => field, 'value' => value }
  end

  describe 'status_update' do
    it 'pasa a APPROVED sin sync manual' do
      described_class.new(channel, change('message_template_status_update',
                                          { 'event' => 'APPROVED', 'message_template_id' => 555 })).perform
      expect(template.reload.status).to eq('APPROVED')
      expect(template.rejection_reason).to be_nil
    end

    it 'guarda rejection_reason en REJECTED' do
      described_class.new(channel, change('message_template_status_update',
                                          { 'event' => 'REJECTED', 'message_template_id' => 555, 'reason' => 'INVALID_FORMAT' })).perform
      expect(template.reload).to have_attributes(status: 'REJECTED', rejection_reason: 'INVALID_FORMAT')
    end

    it 'limpia rejection_reason al salir de REJECTED' do
      template.update!(status: 'REJECTED', rejection_reason: 'INVALID_FORMAT')
      described_class.new(channel, change('message_template_status_update',
                                          { 'event' => 'APPROVED', 'message_template_id' => 555 })).perform
      expect(template.reload.rejection_reason).to be_nil
    end
  end

  describe 'quality_update' do
    it 'actualiza quality_score' do
      described_class.new(channel, change('message_template_quality_update',
                                          { 'message_template_id' => 555, 'new_quality_score' => 'RED' })).perform
      expect(template.reload.quality_score).to eq('RED')
    end
  end

  describe 'casos límite' do
    it 'no revienta si no hay fila local (0 filas)' do
      expect do
        described_class.new(channel, change('message_template_status_update',
                                            { 'event' => 'APPROVED', 'message_template_id' => 999 })).perform
      end.not_to raise_error
    end

    it 'no revienta sin message_template_id' do
      expect do
        described_class.new(channel, change('message_template_status_update', { 'event' => 'APPROVED' })).perform
      end.not_to raise_error
    end
  end
end
