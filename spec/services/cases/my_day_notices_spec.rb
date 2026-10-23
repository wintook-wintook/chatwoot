# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — «Tienes avisos importantes» en Mi día: avisos sin leer con peso.
RSpec.describe Cases::MyDayNotices do
  let(:account) { create(:account, locale: 'es') }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:ticket)  { CaseTicket.create!(account: account, title: 'Falla', contact: contact, assignee: agent) }

  def notify(type, meta = {}, actor = ticket)
    Notification.create!(account: account, user: agent, notification_type: type, primary_actor: actor, meta: meta)
  end

  def notices
    described_class.new(user: agent, account: account).call
  end

  it 'muestra los avisos sin leer con su peso, los pesados primero, y oculta los de peso bajo' do
    medium = notify('case_task_assignment', 'task_title' => 'Llamar')
    high = notify('case_stage_ready', 'needs_doc' => true, 'task_title' => 'Documenta para pasar a Ganada')
    notify('case_task_completed', 'task_title' => 'Hecha')

    expect(notices.map { |n| [n[:id], n[:weight]] }).to eq([[high.id, 'high'], [medium.id, 'medium']])
    expect(notices.first[:link]).to eq(kind: 'case', id: ticket.id, folio: ticket.folio)
  end

  it 'las tareas nuevas pesan alto si alguna es urgente o vence hoy' do
    ticket.case_tasks.create!(account: account, title: 'Hoy', assignee: agent, due_at: 1.hour.from_now)
    notify('case_stage_tasks', 'task_title' => '1 tarea nueva')

    expect(notices.first[:weight]).to eq('high')
  end

  it 'incluye los de conversaciones (mención en rojo) y no los ya leídos' do
    conversation = create(:conversation, account: account)
    notify('conversation_mention', {}, conversation)
    notify('case_task_assignment').update!(read_at: Time.current)

    expect(notices.map { |n| [n[:type], n[:weight], n[:link][:kind]] }).to eq([%w[conversation_mention high conversation]])
  end
end
