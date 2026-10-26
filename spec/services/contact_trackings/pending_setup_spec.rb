# frozen_string_literal: true

require 'rails_helper'

# proyecto@adaptar_prompts_publicados (F5): un agente con datos por configurar no habla.
RSpec.describe ContactTrackings::PendingSetup do
  around { |example| I18n.with_locale(:es) { example.run } }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:pendiente) { 'Eres de <PENDIENTE: Nombre del negocio>. Horario: <PENDIENTE: Horario>. <PENDIENTE: Horario>' }

  describe 'las marcas' do
    it 'junta las de Entrenamiento, Contexto y Objetivo, sin repetir' do
      registro = ContactTracking.new(complementary_prompt: pendiente, ai_context: 'Sin marcas', objective: '<PENDIENTE: Meta>')

      expect(described_class.labels(registro)).to eq('Nombre del negocio, Horario, Meta')
      expect(described_class.blocked?(ContactTracking.new(complementary_prompt: 'Todo listo'))).to be(false)
    end

    it 'ensure! dice qué falta' do
      expect { described_class.ensure!(ContactTracking.new(complementary_prompt: pendiente)) }
        .to raise_error(described_class::Blocked, /Nombre del negocio, Horario/)
    end
  end

  describe 'TrackingTemplate: bandeja' do
    let(:template) { create(:tracking_template, account: account, complementary_prompt: pendiente) }

    it 'no deja asignar bandeja con marcas, y sí cuando ya no hay' do
      expect(template.update(inbox_id: inbox.id)).to be(false)
      expect(template.errors.full_messages.first).to include('Nombre del negocio, Horario')

      expect(template.update(inbox_id: inbox.id, complementary_prompt: 'Eres de Grúas del Norte.')).to be(true)
    end

    it 'no traba ediciones que no tocan ni la bandeja ni el texto' do
      template.update_columns(inbox_id: inbox.id) # rubocop:disable Rails/SkipsModelValidations

      expect(template.reload.update(name: 'Otro nombre')).to be(true)
    end
  end

  describe 'el motor' do
    let(:contact) { create(:contact, account: account) }
    let(:tracking) do
      create(:contact_tracking, account: account, contact: contact, inbox: inbox, status: 'scheduled',
                                complementary_prompt: pendiente)
    end

    it 'ContactTrackingJob: no le escribe al cliente y deja el seguimiento fallido con el motivo' do
      expect(Messages::MessageBuilder).not_to receive(:new)

      ContactTrackingJob.perform_now(tracking.id)

      expect(tracking.reload).to have_attributes(status: 'failed')
      expect(tracking.last_error).to include('Nombre del negocio, Horario')
    end

    it 'ContactTrackingResponseAnalyzerJob: ese seguimiento no contesta' do
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
      message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                                 content: 'hola')

      expect(ContactTrackingResponseAnalyzerJob.new.send(:process_message_for_tracking, tracking, message)).to be(false)
    end
  end
end
