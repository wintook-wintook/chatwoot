# frozen_string_literal: true

require 'rails_helper'

# Ningún caso cerrado deja tareas atoradas: se cancelan o siguen vivas sin caso.
RSpec.describe 'Cerrar un caso con tareas pendientes' do
  let(:account) { create(:account, locale: 'es') }
  let(:agent) { create(:user, account: account, role: :administrator) }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, organization_id: organization.id) }
  let(:ticket) { CaseTicket.create!(account: account, contact: contact, title: 'Caso', organization_id: organization.id, status: :in_progress) }
  let!(:task) { CaseTask.create!(account: account, case_ticket: ticket, title: 'Llamar', assignee: agent, required: true) }
  let(:done) { CaseTask.create!(account: account, case_ticket: ticket, title: 'Hecha', status: :done) }
  let(:api) { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}" }
  let(:headers) { agent.create_new_auth_token }

  def close(extra = {})
    patch "#{api}/transition", params: { status: 'cancelled' }.merge(extra), headers: headers, as: :json
  end

  it 'por defecto las cancela: no cuentan como hechas y no salen en Mi día' do
    done
    close

    expect(response).to have_http_status(:ok)
    expect(task.reload).to have_attributes(status: 'cancelled', cancel_reason: 'case_closed', completed_at: nil)
    expect(task.cancelled_at).to be_present
    expect(done.reload).to be_done
    expect(ticket.case_events.where(event_type: :internal_note).last.payload['content']).to include('1 tarea')

    get "/api/v1/accounts/#{account.id}/case_tasks", params: { mode: 'my_day' }, headers: headers
    expect(response.parsed_body['case_tasks']).to eq([])
  end

  it 'conservar las deja vivas sin caso, en el contacto y en Mi día' do
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, case_task: task, title: 'Cita', starts_at: 1.day.from_now,
                                  ends_at: 2.days.from_now)

    close(pending_tasks: 'keep')

    expect(task.reload).to have_attributes(status: 'pending', case_ticket_id: nil, contact_id: contact.id, organization_id: organization.id,
                                           required: false)
    expect(meeting.reload.case_task_id).to be_nil

    get "/api/v1/accounts/#{account.id}/case_tasks", params: { mode: 'my_day' }, headers: headers
    expect(response.parsed_body['case_tasks'].pluck('id')).to eq([task.id])
  end

  it 'sin responsable, al conservarla queda a quien cierra' do
    task.update!(assignee: nil)

    close(pending_tasks: 'keep')

    expect(task.reload.assignee_id).to eq(agent.id)
  end

  it 'las de «Documenta…» siempre se cancelan' do
    type = CaseType.create!(account: account, name: 'T', color: '#000000')
    column = CaseTypeColumn.create!(account: account, case_type: type, label: 'Etapa', position: 0, statuses: ['open'])
    doc = CaseTask.create!(account: account, case_ticket: ticket, title: 'Documenta', documentation_for_column_id: column.id)

    close(pending_tasks: 'keep')

    expect(doc.reload).to be_cancelled
    expect(task.reload).to be_pending
  end

  it 'cualquier otro cierre también las cancela (reglas, SLA)' do
    ticket.transition!(:cancelled, force: true)

    expect(task.reload).to be_cancelled
  end

  it 'en «Resuelto» no las toca' do
    ticket.transition!(:resolved, force: true)

    expect(task.reload).to be_pending
  end

  it 'al reabrir regresan a pendientes; las hechas y las conservadas no cambian' do
    ticket.update!(status: :closed)
    expect(task.reload).to be_cancelled

    ticket.update!(status: :in_progress)

    expect(task.reload).to have_attributes(status: 'pending', cancelled_at: nil, cancel_reason: nil)
  end

  it 'el avance del proyecto no cuenta los hitos cancelados' do
    milestone = CaseTask.create!(account: account, case_ticket: ticket, title: 'Hito', milestone: true, status: :cancelled)
    CaseTask.create!(account: account, case_ticket: ticket, title: 'Otro', milestone: true, status: :done)

    expect(ticket.project_progress_summary[:progress]).to eq(100)
    expect(milestone.reload).to be_cancelled
  end

  it 'el diálogo de cierre también cancela las tareas agendadas si se pide' do
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Cita', organizer: agent, starts_at: 1.day.from_now,
                                  ends_at: 2.days.from_now)

    close(cancel_meetings: true)

    expect(meeting.reload).to be_cancelled
  end

  describe 'tareas agendadas' do
    def cita(title, starts_at)
      CaseMeeting.create!(account: account, case_ticket: ticket, title: title, organizer: agent, starts_at: starts_at, ends_at: starts_at + 1.hour)
    end

    it 'las que ya pasaron se cancelan solas, sin tocar Google; las futuras no, si no lo pidió' do
      pasada = cita('Pasada', 2.days.ago)
      futura = cita('Futura', 2.days.from_now)
      allow(Cases::Meetings::GoogleMirrorService).to receive(:new)

      close

      expect(pasada.reload).to be_cancelled
      expect(futura.reload).to be_scheduled
      expect(Cases::Meetings::GoogleMirrorService).not_to have_received(:new)
      expect(ticket.case_events.where(event_type: :internal_note).last.payload['content']).to include('ya habían pasado')
    end

    it 'cancelar por columna respeta la decisión de tareas y tareas agendadas' do
      type = CaseType.create!(account: account, name: 'T', color: '#000000')
      ticket.update!(case_type: type)
      column = CaseTypeColumn.create!(account: account, case_type: type, label: 'Cancelada', color: '#000000', position: 9, statuses: ['cancelled'])
      futura = cita('Futura', 2.days.from_now)

      patch "#{api}/move", params: { case_type_column_id: column.id, pending_tasks: 'keep', cancel_meetings: true }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(ticket.reload).to be_cancelled
      expect(task.reload).to have_attributes(status: 'pending', case_ticket_id: nil)
      expect(futura.reload).to be_cancelled
    end
  end

  describe 'reabrir' do
    def agent_with(role_key)
      user = create(:user, account: account, role: :agent)
      role = AccessRole.for_account(account).find { |r| r.key == role_key }
      account.account_users.find_by(user: user).update!(access_role: role)
      user
    end

    def reopen(user, reason = 'Fue un error')
      patch "#{api}/reopen", params: { reason: reason }, headers: user.create_new_auth_token, as: :json
    end

    [[:cancelled, 'cancelado'], [:closed, 'cerrado']].each do |status, name|
      context "with un caso #{name}" do
        before { ticket.update!(status: status, closed_at: (1.day.ago if status == :closed), closure_cause: 'Causa') }

        it 'el administrador lo reabre con motivo: limpia el cierre y regresan sus tareas' do
          reopen(agent)

          expect(response).to have_http_status(:ok)
          expect(ticket.reload).to have_attributes(status: 'in_progress', closed_at: nil, closure_cause: nil, reopen_count: 1)
          expect(task.reload).to be_pending
        end

        it 'el supervisor sí; el técnico, aunque sea responsable, no' do
          tecnico = agent_with('technician')
          ticket.update!(assignee: tecnico)

          reopen(tecnico)
          expect(response).to have_http_status(:forbidden)

          reopen(agent_with('supervisor'))
          expect(ticket.reload).to be_in_progress
        end

        it 'sin motivo no se reabre' do
          reopen(agent, '')

          expect(response).to have_http_status(:unprocessable_entity)
          expect(ticket.reload.status).to eq(status.to_s)
        end

        it 'no sale por Cambiar estado, ni por columna, ni en lote: solo con el botón' do
          patch "#{api}/transition", params: { status: 'in_progress' }, headers: headers, as: :json
          expect(response).to have_http_status(:unprocessable_entity)

          get api, headers: headers
          expect(response.parsed_body['case_ticket']).to include('can_transition_to' => [], 'can_reopen' => true)

          type = CaseType.create!(account: account, name: 'T', color: '#000000')
          ticket.update!(case_type: type)
          proceso = CaseTypeColumn.create!(account: account, case_type: type, label: 'En proceso', color: '#000000', position: 1,
                                           statuses: ['in_progress'])
          patch "#{api}/move", params: { case_type_column_id: proceso.id }, headers: headers, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body['error']).to include('Reabrir')
          expect(ticket.reload.status).to eq(status.to_s)
        end
      end
    end
  end
end
