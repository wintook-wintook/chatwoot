# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — orquestador de alta/edición/borrado.
RSpec.describe Whatsapp::SubmitTemplateService do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:provider) { instance_double(Whatsapp::Providers::WhatsappCloudService) }

  let(:valid_params) do
    {
      name: 'cobro_vencido', language: 'es', category: 'UTILITY',
      body_text: 'Hola {{1}}, saldo {{2}}',
      sample_values: { 'body' => %w[Juan $100] }
    }
  end

  before { allow(channel).to receive(:provider_service).and_return(provider) }

  def result_ok(meta_id: '111', status: 'PENDING')
    Whatsapp::Providers::WhatsappCloudService::TemplateResult.new(success: true, meta_id: meta_id, status: status)
  end

  describe '#create' do
    context 'con DRY_RUN activo' do
      before { allow(GlobalConfigService).to receive(:load).with('WHATSAPP_TEMPLATES_DRY_RUN', false).and_return('true') }

      it 'crea fila PENDING sin llamar a Meta' do
        result = described_class.new(channel: channel, params: valid_params).create

        expect(result).to be_success
        expect(result.template.status).to eq('PENDING')
        expect(result.template.meta_template_id).to start_with('dry-run-')
      end
    end

    context 'sin DRY_RUN' do
      before { allow(GlobalConfigService).to receive(:load).with('WHATSAPP_TEMPLATES_DRY_RUN', false).and_return(false) }

      it 'rechaza payload inválido antes de llamar a Meta' do
        result = described_class.new(channel: channel, params: valid_params.merge(name: 'Mal Nombre')).create

        expect(result).not_to be_success
        expect(result.error).to match(/Nombre/)
      end

      it 'crea en Meta y persiste meta_id + status' do
        allow(provider).to receive(:create_template).and_return(result_ok)

        result = described_class.new(channel: channel, params: valid_params).create

        expect(result).to be_success
        expect(result.template.meta_template_id).to eq('111')
        expect(result.template.status).to eq('PENDING')
      end

      it 'si Meta falla guarda DRAFT + submission_error' do
        allow(provider).to receive(:create_template)
          .and_return(Whatsapp::Providers::WhatsappCloudService::TemplateResult.new(success: false, error: 'nombre duplicado'))

        result = described_class.new(channel: channel, params: valid_params).create

        expect(result).not_to be_success
        expect(result.template.status).to eq('DRAFT')
        expect(result.template.submission_error).to eq('nombre duplicado')
      end

      it 'reporta DRIFT si Meta acepta pero el guardado local falla' do
        allow(provider).to receive(:create_template).and_return(result_ok(meta_id: '222'))
        allow_any_instance_of(WhatsappTemplate).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique.new('dup'))

        result = described_class.new(channel: channel, params: valid_params).create

        expect(result).not_to be_success
        expect(result.drift).to be(true)
        expect(result.error).to include('222')
      end

      # Idempotencia: si ya hay una fila con ese name+language (un DRAFT previo), la reutiliza
      # en vez de crear otra → el save! post-Meta no choca con el índice único (evita el DRIFT).
      it 'reutiliza la fila existente con el mismo name+language sin duplicar' do
        existing = create(:whatsapp_template, account: channel.account, channel_whatsapp: channel,
                                              name: 'cobro_vencido', language: 'es', status: 'DRAFT', meta_template_id: nil)
        allow(provider).to receive(:create_template).and_return(result_ok(meta_id: '333'))

        result = described_class.new(channel: channel, params: valid_params).create

        expect(result).to be_success
        expect(result.template.id).to eq(existing.id)
        expect(result.template.meta_template_id).to eq('333')
        expect(channel.whatsapp_templates.where(name: 'cobro_vencido', language: 'es').count).to eq(1)
      end
    end
  end

  describe '#destroy' do
    it 'borra fila local (dry-run) sin llamar a Meta' do
      template = create(:whatsapp_template, account: channel.account, channel_whatsapp: channel,
                                            meta_template_id: 'dry-run-abc')
      expect(provider).not_to receive(:delete_template)

      expect(described_class.new(template: template).destroy).to be_success
      expect(WhatsappTemplate.exists?(template.id)).to be(false)
    end

    it 'borra en Meta por hsm_id cuando ya existe allá' do
      template = create(:whatsapp_template, account: channel.account, channel_whatsapp: channel, meta_template_id: '999')
      allow(template.channel_whatsapp).to receive(:provider_service).and_return(provider)
      allow(provider).to receive(:delete_template)
        .and_return(Whatsapp::Providers::WhatsappCloudService::TemplateResult.new(success: true))

      expect(described_class.new(template: template).destroy).to be_success
      expect(provider).to have_received(:delete_template).with(name: template.name, meta_template_id: '999')
    end
  end
end
