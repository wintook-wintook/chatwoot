# frozen_string_literal: true

require 'rails_helper'

# Reporte de cierre — ninguna tarea se concluye a mano sin decir qué se hizo.
RSpec.describe 'Task Reports API' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:ticket) { CaseTicket.create!(account: account, contact: contact, title: 'Caso', organization_id: organization.id) }
  let(:api) { "/api/v1/accounts/#{account.id}" }
  let(:headers) { agent.create_new_auth_token }
  let(:task) { CaseTask.create!(account: account, case_ticket: ticket, title: 'Llamar', assignee: agent) }
  let(:loose) { CaseTask.create!(account: account, contact: contact, title: 'Sin caso', assignee: agent, requester: agent) }
  let(:meeting) { CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Visita', organizer: agent, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now) }

  def report(item, type = 'task', extra = {})
    post "#{api}/task_reports", params: { item_type: type, item_id: item.id, content: 'Le llamé y aceptó' }.merge(extra), headers: headers
  end

  def conclude(item_task)
    patch "#{api}/case_tickets/#{ticket.id}/tasks/#{item_task.id}", params: { case_task: { status: 'done' } }, headers: headers, as: :json
  end

  describe 'concluir' do
    it 'sin reporte no se concluye: tarea de caso, sin caso y tarea agendada' do
      conclude(task)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['report_required']).to be(true)
      expect(task.reload).to be_pending

      patch "#{api}/quick_tasks/#{loose.id}", params: { status: 'done' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      patch "#{api}/case_tickets/#{ticket.id}/meetings/#{meeting.id}/hold", params: { status: 'held' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(meeting.reload).to be_scheduled
    end

    it 'con reporte se concluye, lo cierra y entra a la bitácora del caso' do
      outcome = TaskOutcome.ensure_defaults_for(account).first
      report(task, 'task', task_outcome_id: outcome.id)
      expect(response).to have_http_status(:created)
      expect(TaskReport.last.closed_at).to be_nil

      conclude(task)

      expect(task.reload).to be_done
      expect(TaskReport.last).to have_attributes(outcome_label: 'Logrado', contact_id: contact.id, organization_id: organization.id, case_ticket_id: ticket.id)
      expect(TaskReport.last.closed_at).to be_present
      expect(ticket.case_events.where(event_type: :internal_note, case_task_id: task.id).first.payload['content']).to include('Le llamé y aceptó')
    end

    it 'la tarea agendada también, y «no asistió» igual' do
      report(meeting, 'meeting')
      patch "#{api}/case_tickets/#{ticket.id}/meetings/#{meeting.id}/hold", params: { status: 'no_show' }, headers: headers, as: :json

      expect(meeting.reload).to be_no_show
      expect(meeting.task_reports.closed.count).to eq(1)
    end

    it 'la tarea sin caso conserva su contacto y organización en el reporte' do
      report(loose)
      patch "#{api}/quick_tasks/#{loose.id}", params: { status: 'done' }, headers: headers, as: :json

      expect(loose.reload).to be_done
      expect(TaskReport.last).to have_attributes(case_ticket_id: nil, contact_id: contact.id, organization_id: organization.id)
    end

    it 'lo que se concluye solo no pide reporte' do
      task.update!(status: :done)

      expect(task.reload).to be_done
    end

    it 'exige qué se hizo' do
      post "#{api}/task_reports", params: { item_type: 'task', item_id: task.id, content: '  ' }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'reabrir conserva el reporte y al volver a concluir pide uno nuevo' do
      report(task)
      conclude(task)
      patch "#{api}/case_tickets/#{ticket.id}/tasks/#{task.id}", params: { case_task: { status: 'pending' } }, headers: headers, as: :json

      conclude(task)
      expect(response).to have_http_status(:unprocessable_entity)

      report(task)
      conclude(task)
      expect(task.reload).to be_done
      expect(task.task_reports.closed.count).to eq(2)
    end

    it 'reintentar sin concluir deja un solo reporte pendiente' do
      2.times { report(task) }

      expect(task.task_reports.count).to eq(1)
    end

    it 'guarda la evidencia' do
      file = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')
      report(task, 'task', evidence: [file])
      conclude(task)

      get "#{api}/task_reports", params: { case_task_id: task.id }, headers: headers
      expect(response.parsed_body['task_reports'].first['evidence'].first['name']).to eq('avatar.png')
    end

    it 'no se reporta la tarea de otro sin poder ver su caso' do
      role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
      role.update!(areas: role.areas.merge('sales' => 'own', 'service' => 'own', 'agenda' => 'own'))
      account.account_users.find_by(user: agent).update!(access_role: role)
      ajena = CaseTask.create!(account: account, title: 'Ajena', assignee: admin)

      report(ajena)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'consultar' do
    before do
      report(loose)
      patch "#{api}/quick_tasks/#{loose.id}", params: { status: 'done' }, headers: headers, as: :json
    end

    it 'sale en el contacto y en la organización' do
      [{ contact_id: contact.id }, { organization_id: organization.id }].each do |filter|
        get "#{api}/task_reports", params: filter, headers: admin.create_new_auth_token
        expect(response.parsed_body['task_reports'].pluck('title')).to eq(['Sin caso'])
      end
    end

    it 'el supervisor filtra por persona y fechas' do
      auth = admin.create_new_auth_token
      get "#{api}/task_reports", params: { user_id: agent.id, from: 1.day.ago.to_date, to: Time.zone.today }, headers: auth
      expect(response.parsed_body['meta']['count']).to eq(1)

      get "#{api}/task_reports", params: { user_id: admin.id }, headers: auth
      expect(response.parsed_body['meta']['count']).to eq(0)
    end

    it 'con Agenda en «solo lo suyo» ve solo los propios' do
      role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
      role.update!(areas: role.areas.merge('agenda' => 'own'))
      otro = create(:user, account: account, role: :agent)
      account.account_users.find_by(user: otro).update!(access_role: role)

      get "#{api}/task_reports", headers: otro.create_new_auth_token

      expect(response.parsed_body['task_reports']).to eq([])
    end
  end

  describe 'catálogo' do
    it 'nace con los cuatro resultados, y solo quien tiene Ajustes lo cambia' do
      get "#{api}/task_outcomes", headers: headers
      expect(response.parsed_body['task_outcomes'].pluck('label')).to eq(['Logrado', 'No contestó', 'Reprogramar', 'No se pudo'])

      role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
      account.account_users.find_by(user: agent).update!(access_role: role)
      post "#{api}/task_outcomes", params: { task_outcome: { label: 'Nuevo' } }, headers: headers, as: :json
      expect(response).to have_http_status(:forbidden)

      post "#{api}/task_outcomes", params: { task_outcome: { label: 'Vendido' } }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:created)
    end
  end
end
