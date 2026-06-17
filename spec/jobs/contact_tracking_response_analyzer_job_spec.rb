# frozen_string_literal: true

require 'rails_helper'

# proyecto@ai_agent_attachments
RSpec.describe ContactTrackingResponseAnalyzerJob do
  subject(:job) { described_class.new }

  let(:account) { create(:account) }
  let(:tracking_template) { create(:tracking_template, account: account) }
  let(:tracking) { ContactTracking.new(account: account, tracking_template: tracking_template) }

  describe '#resolve_attachment_directives' do
    let!(:attachment) do
      create(:ai_agent_attachment, tracking_template: tracking_template, account: account, name: 'catalogo')
    end

    it 'resolves an existing directive and strips the token from the text' do
      content = 'Aquí tienes @adjunto:catalogo y nada más.'
      clean, signed_ids = job.send(:resolve_attachment_directives, tracking, content)

      expect(clean).to eq('Aquí tienes y nada más.')
      expect(signed_ids.size).to eq(1)
    end

    it 'returns the signed_id of the existing blob (reuses storage)' do
      _clean, signed_ids = job.send(:resolve_attachment_directives, tracking, '@adjunto:catalogo')
      expect(signed_ids.first).to eq(attachment.file.blob.signed_id)
    end

    it 'ignores unknown directives without breaking the rest' do
      content = 'Mira @adjunto:catalogo pero no @adjunto:inexistente.'
      clean, signed_ids = job.send(:resolve_attachment_directives, tracking, content)

      expect(signed_ids.size).to eq(1)
      expect(clean).to eq('Mira pero no.')
    end

    it 'is case-insensitive when resolving the name' do
      _clean, signed_ids = job.send(:resolve_attachment_directives, tracking, '@adjunto:CATALOGO')
      expect(signed_ids.size).to eq(1)
    end

    it 'resolves the name and strips a trailing extension the IA may append' do
      content = 'Te envío la ficha. @adjunto:catalogo.svg'
      clean, signed_ids = job.send(:resolve_attachment_directives, tracking, content)

      expect(signed_ids.size).to eq(1)
      expect(clean).to eq('Te envío la ficha.')
    end

    it 'returns the content unchanged when the agent has no template' do
      orphan = ContactTracking.new(account: account, tracking_template: nil)
      clean, signed_ids = job.send(:resolve_attachment_directives, orphan, 'texto @adjunto:catalogo')

      expect(clean).to eq('texto @adjunto:catalogo')
      expect(signed_ids).to be_empty
    end

    it 'caps the number of attachments at MAX_DIRECTIVE_ATTACHMENTS' do
      stub_const("#{described_class}::MAX_DIRECTIVE_ATTACHMENTS", 1)
      create(:ai_agent_attachment, tracking_template: tracking_template, account: account, name: 'precios')

      _clean, signed_ids = job.send(:resolve_attachment_directives, tracking, '@adjunto:catalogo @adjunto:precios')
      expect(signed_ids.size).to eq(1)
    end
  end
end
