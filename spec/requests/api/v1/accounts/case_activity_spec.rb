# frozen_string_literal: true

require 'rails_helper'

# Plan Actividad del caso — todo lo que pasó en el caso en una sola lista, y lo que
# el usuario hace (tareas, cotizaciones) queda en la bitácora.
RSpec.describe 'Case Activity API' do
  let(:account)  { create(:account) }
  let(:admin)    { create(:user, account: account, role: :administrator) }
  let(:contact)  { create(:contact, account: account) }
  let(:soporte)  { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket)   { CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte) }
  let(:url)      { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/activity" }

  def message(conversation, type, content, at)
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: type,
                     content: content, created_at: at)
  end

  describe 'GET activity' do
    let(:chat)  { create(:conversation, account: account, contact: contact) }
    let(:email) { create(:conversation, account: account, contact: contact) }

    before do
      ticket.update!(conversation: chat)
      ticket.extra_conversation_links.create!(account: account, conversation: email)
      # 18:00 y 23:30 de México el 1 nov (00:00 y 05:30 UTC del 2 nov) → mismo día local.
      message(chat, :incoming, 'Hola, sigue fallando', Time.utc(2026, 11, 2, 0, 0))
      message(chat, :outgoing, 'Vamos para allá', Time.utc(2026, 11, 2, 5, 30))
      message(email, :incoming, 'Adjunto la factura', Time.utc(2026, 11, 2, 15, 0))
      create(:message, account: account, inbox: chat.inbox, conversation: chat, message_type: :outgoing,
                       private: true, content: 'nota privada')
    end

    it 'resume los mensajes de todas las conversaciones por día local y conversación' do
      get url, params: { tz: 'America/Mexico_City' }, headers: admin.create_new_auth_token, as: :json

      groups = response.parsed_body['items'].select { |i| i['kind'] == 'messages' }
      expect(groups.size).to eq(2)
      chat_day = groups.find { |g| g['conversation']['display_id'] == chat.display_id }
      expect(chat_day).to include('day' => '2026-11-01', 'incoming' => 1, 'outgoing' => 1)
      expect(chat_day['last']).to include('content' => 'Vamos para allá', 'incoming' => false)
      expect(chat_day['conversation']['primary']).to be(true)
      email_day = groups.find { |g| g['conversation']['display_id'] == email.display_id }
      expect(email_day).to include('day' => '2026-11-02', 'incoming' => 1, 'outgoing' => 0)
    end

    it 'mezcla la bitácora con los mensajes, de lo más nuevo a lo más viejo' do
      get url, params: { tz: 'America/Mexico_City' }, headers: admin.create_new_auth_token, as: :json

      times = response.parsed_body['items'].map { |i| Time.zone.parse(i['at']) }
      expect(times).to eq(times.sort.reverse)
      expect(response.parsed_body['items'].pluck('kind')).to include('event', 'messages')
    end

    it 'da el resumen: qué sigue, atrasos y el último contacto' do
      ticket.case_tasks.create!(account: account, title: 'Atrasada', due_at: 1.day.ago)
      ticket.case_tasks.create!(account: account, title: 'Luego', due_at: 2.days.from_now)
      get url, headers: admin.create_new_auth_token, as: :json

      summary = response.parsed_body['summary']
      expect(summary['next_task']['title']).to eq('Atrasada')
      expect(summary).to include('overdue_tasks' => 1, 'pending_tasks' => 2)
      expect(summary['last_incoming']['conversation']['display_id']).to eq(email.display_id)
      expect(summary['last_outgoing']['conversation']['display_id']).to eq(chat.display_id)
    end
  end

  describe 'bitácora de tareas' do
    before { Current.user = admin }
    after { Current.reset }

    it 'anota creada, completada, reabierta, cancelada y borrada' do
      task = ticket.case_tasks.create!(account: account, title: 'Llamar')
      task.update!(status: :done)
      task.update!(status: :pending)
      task.update!(status: :cancelled)
      task.destroy!

      events = ticket.case_events.where('event_type >= ?', CaseEvent.event_types[:task_created]).order(:id)
      expect(events.map(&:event_type)).to eq(%w[task_created task_completed task_reopened task_cancelled task_deleted])
      expect(events.first.payload).to include('title' => 'Llamar', 'sequence' => 1)
      expect(events.first.actor).to eq(admin)
    end

    it 'no anota al nacer las tareas de la plantilla de etapa' do
      column = CaseTypeColumn.create!(account: account, case_type: soporte, label: 'Diagnóstico', position: 1,
                                      statuses: ['open'])
      template = CaseTypeColumnTask.create!(account: account, case_type_column: column, title: 'Revisar')
      ticket.case_tasks.create!(account: account, title: 'Revisar', case_type_column_task: template)

      expect(ticket.case_events.task_created).to be_empty
    end

    it 'no anota nada en tareas sin caso' do
      expect { CaseTask.create!(account: account, title: 'Suelta', contact: contact) }.not_to change(CaseEvent, :count)
    end
  end

  describe 'bitácora de cotizaciones' do
    it 'anota la cotización creada y su cambio de estado en el caso del que salió' do
      quote = account.quotes.create!(contact: contact, origin_ticket: ticket)
      quote.update!(status: :sent)

      created, changed = ticket.case_events.where(event_type: %i[quote_created quote_status_changed]).order(:id).to_a
      expect(created.event_type).to eq('quote_created')
      expect(changed.payload).to include('folio' => quote.folio, 'from' => 'draft', 'to' => 'sent')
    end
  end
end
