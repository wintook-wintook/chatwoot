# frozen_string_literal: true

require 'rails_helper'

# Nota privada y aviso al administrador tras agendar (o al detectar interés/rechazo).
# Los dos fallaban siempre en silencio: la nota por llamar a MessageBuilder con keywords,
# el aviso por buscar el rol en users.role (vive en account_users).
RSpec.describe ContactTrackingResponseAnalyzerJob do
  let(:account)      { create(:account) }
  let(:inbox)        { create(:inbox, account: account) }
  let(:contact)      { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message)      { create(:message, account: account, inbox: inbox, conversation: conversation, content: '2') }
  let(:tracking)     { create(:contact_tracking, account: account, contact: contact, inbox: inbox) }
  let(:admin)        { create(:user, account: account, role: :administrator) }
  let(:job)          { described_class.new }

  # Un agente creado antes que el admin: users.first sería él, no el administrador.
  before { create(:user, account: account, role: :agent) }

  it 'crea la nota privada en la conversación' do
    job.send(:create_private_note, tracking, message, '📅 Cita agendada: lunes 21 09:30')

    nota = conversation.messages.where(private: true).last
    expect(nota.content).to eq('📅 Cita agendada: lunes 21 09:30')
    expect(nota).to be_outgoing
  end

  it 'asigna la conversación a un administrador de la cuenta y le avisa' do
    admin # después del agente del before: users.first no es el administrador
    expect { job.send(:notify_admin_interested, tracking, message) }.to change(Notification, :count).by(1)

    expect(conversation.reload.assignee).to eq(admin)
    expect(Notification.last.user).to eq(admin)
  end
end
