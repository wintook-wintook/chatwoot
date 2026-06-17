# frozen_string_literal: true

require 'rails_helper'

# proyecto@ai_agent_attachments
RSpec.describe AiAgentAttachments::DirectiveReferenceService do
  let(:account) { create(:account) }
  let(:template) { create(:tracking_template, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox) { create(:inbox, account: account) }

  def build_tracking(prompt, status: 'scheduled')
    ContactTracking.create!(
      account: account, contact: contact, inbox: inbox,
      objective: 'objetivo de prueba', scheduled_for: 1.hour.from_now,
      status: status, tracking_template_id: template.id,
      complementary_prompt: prompt
    )
  end

  describe '.rename' do
    it 'reescribe la referencia en el prompt del agente' do
      template.update!(complementary_prompt: 'Envía @adjunto:catalogo ahora')
      described_class.rename(template, 'catalogo', 'catalogo_2026')
      expect(template.reload.complementary_prompt).to eq('Envía @adjunto:catalogo_2026 ahora')
    end

    it 'reescribe el prompt congelado de seguimientos vivos' do
      tracking = build_tracking('Manda @adjunto:catalogo por favor')
      described_class.rename(template, 'catalogo', 'catalogo_2026')
      expect(tracking.reload.complementary_prompt).to eq('Manda @adjunto:catalogo_2026 por favor')
    end

    it 'no toca un nombre más largo con el mismo prefijo' do
      template.update!(complementary_prompt: '@adjunto:cat y @adjunto:catalogo')
      described_class.rename(template, 'cat', 'gato')
      expect(template.reload.complementary_prompt).to eq('@adjunto:gato y @adjunto:catalogo')
    end

    it 'no toca seguimientos finalizados' do
      tracking = build_tracking('@adjunto:catalogo', status: 'completed')
      described_class.rename(template, 'catalogo', 'catalogo_2026')
      expect(tracking.reload.complementary_prompt).to eq('@adjunto:catalogo')
    end

    it 'es no-op cuando el nombre nuevo es igual al anterior' do
      template.update!(complementary_prompt: '@adjunto:catalogo')
      expect { described_class.rename(template, 'catalogo', 'catalogo') }
        .not_to(change { template.reload.complementary_prompt })
    end
  end

  describe '.remove' do
    it 'quita la referencia colgante del agente y de los seguimientos vivos' do
      template.update!(complementary_prompt: 'Texto @adjunto:catalogo fin')
      tracking = build_tracking('Hola @adjunto:catalogo chau')
      described_class.remove(template, 'catalogo')
      expect(template.reload.complementary_prompt).to eq('Texto fin')
      expect(tracking.reload.complementary_prompt).to eq('Hola chau')
    end
  end
end
