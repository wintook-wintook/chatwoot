# frozen_string_literal: true

require 'rails_helper'

# Reglas de casos: «Notificar usuario», «Agregar etiqueta» y «Activar seguimiento» sí hacen algo.
RSpec.describe Cases::RuleEngineService do
  let(:account) { create(:account) }
  let(:boss) { create(:user, account: account, email: 'jefa@empresa.test') }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) do
    CaseTicket.create!(account: account, contact: contact, conversation: conversation, case_type: soporte, title: 'Falla')
  end

  def rule(type, value)
    CaseRule.create!(account: account, name: 'Urgentes', active: true, conditions: [],
                     actions: [{ 'type' => type, 'value' => value }])
  end

  def run
    described_class.new(ticket).evaluate!
  end

  it 'Notificar usuario deja un aviso en su campanita' do
    rule('notify_agent', 'JEFA@empresa.test')
    expect { run }.to change { Notification.where(user: boss, notification_type: 'case_rule_notice').count }.by(1)
    notice = Notification.where(user: boss).last
    expect(notice.primary_actor).to eq(ticket)
    expect(notice.push_message_body).to include('Urgentes', 'Falla')
  end

  it 'Agregar etiqueta etiqueta la conversación del caso' do
    account.labels.create!(title: 'urgente')
    rule('add_label', 'Urgente')
    run
    expect(conversation.reload.label_list).to include('urgente')
  end

  it 'Activar seguimiento arranca la plantilla en la conversación del caso' do
    template = account.tracking_templates.create!(name: 'Cobranza', objective: 'Cobrar la factura pendiente')
    rule('trigger_tracking', 'cobranza')
    run
    expect(ContactTracking.where(contact: contact, tracking_template_id: template.id)).to exist
  end

  it 'sin usuario, etiqueta o plantilla que coincida no hace nada' do
    rule('add_label', 'no existe')
    expect { run }.not_to raise_error
    expect(conversation.reload.label_list).to be_empty
  end
end
