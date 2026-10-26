# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — revisión de conversaciones: la evidencia
RSpec.describe ContactTrackings::Assistant::ConversationEvidence do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe '.display_id_in' do
    it 'lee el número del link de la conversación' do
      expect(described_class.display_id_in("revisa /app/accounts/#{account.id}/conversations/173 por favor", account)).to eq(173)
    end

    it 'lee el link copiado desde una bandeja, etiqueta, equipo o vista' do
      %w[inbox/493 label/ventas team/3 custom_view/7 mentions unattended].each do |medio|
        expect(described_class.display_id_in("/app/accounts/#{account.id}/#{medio}/conversations/186 revisa", account)).to eq(186)
      end
    end

    it 'ignora un link de otra cuenta' do
      expect(described_class.display_id_in('/app/accounts/999999/conversations/173', account)).to be_nil
    end

    it 'acepta «conversación 173»' do
      expect(described_class.display_id_in('mira la conversación #173', account)).to eq(173)
    end

    it 'nil si no hay ninguna' do
      expect(described_class.display_id_in('un agente para un gimnasio', account)).to be_nil
    end
  end

  it 'no encuentra conversaciones de otra cuenta' do
    otra = create(:conversation)

    expect(described_class.new(account, otra.display_id).found?).to be(otra.account_id == account.id)
  end

  it 'arma los turnos con quién habló, enmascarados' do
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming,
                     content: 'mi correo es ana@example.com')
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing,
                     content: 'Listo', content_attributes: { sentiment_auto_reply: true })
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing,
                     content: 'Hola, soy Ana del equipo')
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing,
                     private: true, content: 'Cita agendada')

    turnos = described_class.new(account, conversation.display_id).turns

    expect(turnos.map(&:role)).to eq(%w[cliente bot humano nota])
    expect(turnos.first.content).to eq('mi correo es [correo]')
  end

  describe 'el Entrenamiento que corrió' do
    let(:template) { create(:tracking_template, account: account, complementary_prompt: 'nuevo', calendar_integration_ids: []) }
    let!(:tracking) do
      create(:contact_tracking, account: account, inbox: inbox, conversation: conversation,
                                tracking_template: template, complementary_prompt: 'viejo')
    end

    it 'es la copia del seguimiento, y avisa que el agente cambió después' do
      evidencia = described_class.new(account, conversation.display_id)

      expect(evidencia.tracking).to eq(tracking)
      expect(evidencia.ran_prompt).to eq('viejo')
      expect(evidencia.stale_copy?).to be(true)
    end
  end
end
