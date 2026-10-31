# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — orquestador de alta/edición/borrado.
RSpec.describe Whatsapp::SubmitTemplateService do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:provider) { instance_double(Whatsapp::Providers::WhatsappCloudService) }

  let(:valid_params) do
    {
      name: 'cobro_vencido', language: 'es', category: 'UTILITY',
      body_text: 'Hola {{1}}, saldo {{2}}.',
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

  # feat/plantillas_whatsapp_mejoras F0
  describe 'archivo de muestra de la cabecera' do
    before { allow(GlobalConfigService).to receive(:load).with('WHATSAPP_TEMPLATES_DRY_RUN', false).and_return(false) }

    def upload_ok(handle = 'H-NUEVO')
      Whatsapp::ResumableUploadService::Result.new(success: true, handle: handle)
    end

    %w[image video document].each do |tipo|
      it "sube la muestra de #{tipo} y manda su handle a Meta" do
        servicio = instance_double(Whatsapp::ResumableUploadService, perform: upload_ok)
        allow(Whatsapp::ResumableUploadService).to receive(:new).and_return(servicio)
        allow(provider).to receive(:create_template).and_return(result_ok)

        result = described_class.new(channel: channel, params: valid_params.merge(
          header_type: tipo, header_media_url: "https://cdn.example.com/muestra.#{tipo}"
        )).create

        expect(result).to be_success
        expect(Whatsapp::ResumableUploadService).to have_received(:new)
          .with(channel: channel, media_url: "https://cdn.example.com/muestra.#{tipo}", header_type: tipo)
        expect(provider).to have_received(:create_template) do |payload|
          header = payload[:components].find { |c| c[:type] == 'HEADER' }
          expect(header).to eq(type: 'HEADER', format: tipo.upcase, example: { header_handle: ['H-NUEVO'] })
        end
      end
    end

    it 'con el archivo subido en la pantalla (F6) sube ese archivo como muestra' do
      blob = ActiveStorage::Blob.create_and_upload!(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'f.pdf',
                                                    content_type: 'application/pdf')
      allow(Whatsapp::ResumableUploadService).to receive(:new).and_return(instance_double(Whatsapp::ResumableUploadService,
                                                                                          perform: upload_ok))
      allow(provider).to receive(:create_template).and_return(result_ok)

      described_class.new(channel: channel, params: valid_params.merge(header_type: 'document', header_sample: blob.signed_id)).create

      expect(Whatsapp::ResumableUploadService).to have_received(:new)
        .with(channel: channel, media_url: include('/rails/active_storage/'), header_type: 'document')
    end

    it 'si la subida falla no llama a Meta' do
      fallo = Whatsapp::ResumableUploadService::Result.new(success: false, error: 'El video supera 16 MB')
      allow(Whatsapp::ResumableUploadService).to receive(:new).and_return(instance_double(Whatsapp::ResumableUploadService,
                                                                                          perform: fallo))
      allow(provider).to receive(:create_template)

      result = described_class.new(channel: channel, params: valid_params.merge(
        header_type: 'video', header_media_url: 'https://cdn.example.com/v.mp4'
      )).create

      expect(result.error).to eq('El video supera 16 MB')
      expect(provider).not_to have_received(:create_template)
    end

    it 'al editar con otra liga vuelve a subir la muestra' do
      template = create(:whatsapp_template, channel_whatsapp: channel, account: channel.account, status: 'REJECTED',
                                            meta_template_id: '999', header_type: 'video',
                                            header_media_url: 'https://cdn.example.com/viejo.mp4', header_handle: 'H-VIEJO')
      allow(Whatsapp::ResumableUploadService).to receive(:new).and_return(instance_double(Whatsapp::ResumableUploadService,
                                                                                          perform: upload_ok))
      allow(provider).to receive(:edit_template).and_return(result_ok)

      described_class.new(template: template, params: { header_media_url: 'https://cdn.example.com/nuevo.mp4' }).update

      expect(template.reload.header_handle).to eq('H-NUEVO')
    end
  end

  # feat/plantillas_whatsapp_mejoras F10: «Guardar borrador» (D10b).
  describe '#save_draft' do
    before { allow(GlobalConfigService).to receive(:load).with('WHATSAPP_TEMPLATES_DRY_RUN', false).and_return(false) }

    it 'guarda una plantilla a medias como DRAFT sin llamar a Meta ni exigir sus reglas' do
      allow(provider).to receive(:create_template)

      result = described_class.new(channel: channel, params: { name: 'a_medias', language: 'es', body_text: '{{1}}' }).save_draft

      expect(result).to be_success
      expect(result.template).to have_attributes(status: 'DRAFT', meta_template_id: nil, body_text: '{{1}}')
      expect(result.template).to be_editable
      expect(provider).not_to have_received(:create_template)
    end

    it 'guarda quién la creó (las sincronizadas desde Meta quedan sin autor)' do
      usuario = create(:user, account: channel.account)

      result = described_class.new(channel: channel, params: { name: 'con_autor', language: 'es' }, user: usuario).save_draft

      expect(result.template.created_by).to eq(usuario)
    end

    it 'sin nombre no se puede guardar' do
      result = described_class.new(channel: channel, params: { name: '', language: 'es' }).save_draft

      expect(result).not_to be_success
    end

    it 'una plantilla que ya está en Meta no se regresa a borrador' do
      create(:whatsapp_template, channel_whatsapp: channel, account: channel.account, name: 'cobro_vencido', language: 'es',
                                 status: 'APPROVED', meta_template_id: '555')

      result = described_class.new(channel: channel, params: valid_params).save_draft

      expect(result).not_to be_success
      expect(result.error).to include('ya está en Meta')
    end

    it 'un borrador se manda a revisión como plantilla nueva (crear, no editar)' do
      allow(provider).to receive(:create_template).and_return(result_ok(meta_id: '777'))
      borrador = described_class.new(channel: channel, params: { name: 'cobro_vencido', language: 'es' }).save_draft.template

      result = described_class.new(template: borrador, params: valid_params).update

      expect(result).to be_success
      expect(result.template).to have_attributes(status: 'PENDING', meta_template_id: '777')
      expect(provider).to have_received(:create_template)
    end

    it 'un borrador incompleto no se manda: dice qué falta' do
      borrador = described_class.new(channel: channel, params: { name: 'a_medias', language: 'es' }).save_draft.template

      result = described_class.new(template: borrador, params: {}).update

      expect(result).not_to be_success
      expect(result.error).to include('Mensaje')
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

    # feat/plantillas_whatsapp_mejoras: si no, los selectores la siguen ofreciendo.
    it 'la quita de la lista del canal (solo ese idioma)' do
      channel.update!(message_templates: [{ 'name' => 'x', 'language' => 'es' }, { 'name' => 'x', 'language' => 'en' },
                                          { 'name' => 'y', 'language' => 'es' }])
      template = create(:whatsapp_template, channel_whatsapp: channel, account: channel.account, name: 'x', language: 'es',
                                            status: 'APPROVED', meta_template_id: '999')
      allow(provider).to receive(:delete_template).and_return(result_ok)

      expect(described_class.new(template: template).destroy).to be_success
      expect(channel.reload.message_templates).to eq([{ 'name' => 'x', 'language' => 'en' }, { 'name' => 'y', 'language' => 'es' }])
    end
  end
end
