# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — operaciones de plantilla del provider (create/edit/delete) contra Meta.
describe Whatsapp::Providers::WhatsappCloudService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:json) { { 'Content-Type' => 'application/json' } }
  let(:base) { 'https://graph.facebook.com/v14.0/123456789' }

  describe '#create_template' do
    it 'devuelve meta_id y status en éxito' do
      stub_request(:post, "#{base}/message_templates")
        .to_return(status: 200, body: { id: '111', status: 'PENDING' }.to_json, headers: json)

      result = service.create_template({ name: 'x', language: 'es' })
      expect(result).to have_attributes(success: true, meta_id: '111', status: 'PENDING')
    end

    it 'marca rate_limited en 429' do
      stub_request(:post, "#{base}/message_templates").to_return(status: 429, body: '{}', headers: json)

      result = service.create_template({})
      expect(result.success?).to be(false)
      expect(result.rate_limited).to be(true)
      expect(result.error).to match(/creación/)
    end

    it 'extrae el mensaje de error de Meta' do
      stub_request(:post, "#{base}/message_templates")
        .to_return(status: 400, body: { error: { message: 'nombre inválido' } }.to_json, headers: json)

      result = service.create_template({})
      expect(result).to have_attributes(success: false, error: 'nombre inválido')
    end
  end

  describe '#edit_template' do
    it 'hace POST al nodo de la plantilla' do
      stub = stub_request(:post, "#{base.sub('/123456789', '')}/999")
             .with(body: { components: [{ type: 'BODY', text: 'y' }] }.to_json)
             .to_return(status: 200, body: { success: true }.to_json, headers: json)

      result = service.edit_template('999', components: [{ type: 'BODY', text: 'y' }])
      expect(result.success?).to be(true)
      expect(stub).to have_been_requested
    end
  end

  describe '#delete_template' do
    it 'borra por hsm_id' do
      stub = stub_request(:delete, "#{base}/message_templates")
             .with(query: { name: 'foo', hsm_id: '999' })
             .to_return(status: 200, body: { success: true }.to_json, headers: json)

      expect(service.delete_template(name: 'foo', meta_template_id: '999').success?).to be(true)
      expect(stub).to have_been_requested
    end

    it '404 es no-op (éxito)' do
      stub_request(:delete, "#{base}/message_templates").with(query: hash_including({}))
                                                        .to_return(status: 404, body: '{}', headers: json)

      expect(service.delete_template(name: 'foo').success?).to be(true)
    end
  end
end
