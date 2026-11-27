# frozen_string_literal: true

require 'rails_helper'

# proyecto@ai_agent_attachments
RSpec.describe AiAgentAttachment do
  describe 'associations' do
    it { is_expected.to belong_to(:tracking_template).optional } # o es de una Campaña con Vendedor IA
    it { is_expected.to belong_to(:tracking_campaign).optional }
    it { is_expected.to belong_to(:account) }
  end

  describe 'validations' do
    it 'is valid with a slug name and an attached file' do
      expect(build(:ai_agent_attachment)).to be_valid
    end

    it 'requires a name' do
      attachment = build(:ai_agent_attachment, name: '')
      expect(attachment).not_to be_valid
      expect(attachment.errors[:name]).to be_present
    end

    it 'rejects names with spaces or invalid characters' do
      attachment = build(:ai_agent_attachment, name: 'mi archivo')
      expect(attachment).not_to be_valid
      expect(attachment.errors[:name].join).to match(/letras/)
    end

    it 'requires an attached file' do
      attachment = build(:ai_agent_attachment, file: nil)
      expect(attachment).not_to be_valid
      expect(attachment.errors[:file]).to be_present
    end

    it 'enforces unique name per tracking_template (case-insensitive)' do
      existing = create(:ai_agent_attachment, name: 'catalogo')
      duplicate = build(:ai_agent_attachment,
                        tracking_template: existing.tracking_template,
                        account: existing.account,
                        name: 'CATALOGO')
      expect(duplicate).not_to be_valid
    end

    it 'allows the same name in a different agent' do
      existing = create(:ai_agent_attachment, name: 'catalogo')
      other_template = create(:tracking_template, account: existing.account)
      other = build(:ai_agent_attachment,
                    tracking_template: other_template,
                    account: existing.account,
                    name: 'catalogo')
      expect(other).to be_valid
    end
  end

  describe 'lo que WhatsApp acepta (al subir)' do
    it 'una imagen que no es JPG ni PNG, o muy pesada, no se sube' do
      gif = build(:ai_agent_attachment, file: Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/sample.png'), 'image/png'))
      gif.file.blob.content_type = 'image/gif'
      expect(gif).not_to be_valid
      expect(gif.errors[:file].join).to include('JPG o PNG')

      png = build(:ai_agent_attachment, file: Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/sample.png'), 'image/png'))
      expect(png).to be_valid
    end
  end
end
