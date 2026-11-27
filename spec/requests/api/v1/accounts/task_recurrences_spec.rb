# frozen_string_literal: true

require 'rails_helper'

# Tareas que se repiten: una tarea fija que Kontrolya vuelve a crear cada cierto tiempo.
RSpec.describe 'Task recurrences' do
  let(:account) { create(:account) }
  let(:ana) { create(:user, account: account, role: :administrator, name: 'Ana') }
  let(:beto) { create(:user, account: account, role: :agent, name: 'Beto') }
  let(:contact) { create(:contact, account: account, name: 'Grúas Monterrey') }
  let(:api) { "/api/v1/accounts/#{account.id}/task_recurrences" }
  let(:monday) { Date.new(2026, 11, 23) } # lunes

  def recurrence(attrs = {})
    TaskRecurrence.create!({ account: account, user: ana, assignee: ana, title: 'Llamar a Grúas', starts_on: monday,
                             time_zone: 'America/Mexico_City' }.merge(attrs))
  end

  def run(rec) = TaskRecurrences::Generator.new(rec.reload).call

  describe 'Cadence' do
    it 'cada semana en ciertos días y cada 2 semanas' do
      weekly = recurrence(unit: 'week', weekdays: [1, 4])
      expect(weekly.cadence.first_on).to eq(monday)
      expect(weekly.cadence.next_after(monday)).to eq(monday + 3) # jueves

      biweekly = recurrence(unit: 'week', every: 2, weekdays: [1])
      expect(biweekly.cadence.next_after(monday)).to eq(monday + 14)
    end

    it 'cada mes (fin de mes) y cada N días' do
      monthly = recurrence(unit: 'month', starts_on: Date.new(2027, 1, 31))
      expect(monthly.cadence.next_after(Date.new(2027, 1, 31))).to eq(Date.new(2027, 2, 28))
      expect(monthly.cadence.next_after(Date.new(2027, 2, 28))).to eq(Date.new(2027, 3, 31))

      daily = recurrence(unit: 'day', every: 3)
      expect(daily.cadence.next_after(monday)).to eq(monday + 3)
    end
  end

  describe 'Generator' do
    it 'fecha fija: crea la tarea del día; si sigue pendiente la siguiente vez, cuenta como no hecha y avisa' do # rubocop:disable RSpec/MultipleExpectations -- un recorrido de 3 semanas
      travel_to(monday.in_time_zone('America/Mexico_City').change(hour: 9)) do
        rec = recurrence(unit: 'week', weekdays: [1], assignee: beto, contact: contact)
        TaskRecurrences::Schedule.start!(rec)
        task = rec.case_tasks.last
        expect(task).to have_attributes(title: 'Llamar a Grúas', assignee_id: beto.id, requester_id: ana.id, planned_on: monday,
                                        contact_id: contact.id)
        expect(rec.reload.next_on).to eq(monday + 7)
        run(rec)
        expect(rec.case_tasks.count).to eq(1) # el mismo día no se duplica
      end

      travel_to((monday + 7).in_time_zone('America/Mexico_City').change(hour: 9)) do
        rec = TaskRecurrence.last
        run(rec)
        expect(rec.reload).to have_attributes(missed_count: 1, next_on: monday + 14)
        expect(rec.case_tasks.count).to eq(1)
        expect(beto.notifications.where(notification_type: 'task_recurrence_missed').count).to eq(1)
        expect(I18n.with_locale(:es) { beto.notifications.last.push_message_title }).to eq('No se hizo «Llamar a Grúas»')
        expect(ana.notifications.where(notification_type: 'task_recurrence_missed').count).to eq(1)
      end

      travel_to((monday + 14).in_time_zone('America/Mexico_City').change(hour: 9)) do
        rec = TaskRecurrence.last
        rec.case_tasks.last.update!(status: :done)
        run(rec)
        expect(rec.case_tasks.count).to eq(2)
      end
    end

    it 'después de hacerla: espera a que la concluya y cuenta el intervalo desde ese día' do
      travel_to(monday.in_time_zone('America/Mexico_City').change(hour: 9)) do
        TaskRecurrences::Schedule.start!(recurrence(mode: 'after_done', unit: 'day', every: 30))
      end
      rec = TaskRecurrence.last
      expect(rec.next_on).to be_nil
      travel_to((monday + 10).in_time_zone('America/Mexico_City').change(hour: 9)) do
        run(rec)
        expect(rec.reload.case_tasks.count).to eq(1) # sigue pendiente: no crea otra
        rec.case_tasks.last.update!(status: :done)
        run(rec)
        expect(rec.reload.next_on).to eq(monday + 40)
      end
      travel_to((monday + 40).in_time_zone('America/Mexico_City').change(hour: 9)) do
        run(rec)
        expect(rec.reload.case_tasks.count).to eq(2)
      end
    end

    it 'con hora crea una tarea agendada y termina al llegar a su número de veces' do
      allow(Cases::MeetingSyncJob).to receive(:perform_later)
      travel_to(monday.in_time_zone('America/Mexico_City').change(hour: 7)) do
        rec = recurrence(unit: 'day', at_time: '10:30', max_count: 1, estimated_minutes: 45)
        TaskRecurrences::Schedule.start!(rec)
        meeting = rec.case_meetings.last
        expect(meeting.starts_at.in_time_zone('America/Mexico_City').strftime('%H:%M')).to eq('10:30')
        expect(meeting.ends_at - meeting.starts_at).to eq(45.minutes)
      end
      travel_to((monday + 1).in_time_zone('America/Mexico_City').change(hour: 7)) do
        rec = TaskRecurrence.last
        rec.case_meetings.last.update_columns(status: CaseMeeting.statuses[:held]) # rubocop:disable Rails/SkipsModelValidations
        run(rec)
        expect(rec.reload.status).to eq('ended')
        expect(rec.case_meetings.count).to eq(1)
      end
    end
  end

  describe 'API' do
    it 'cada usuario programa la suya; con «solo lo suyo» el responsable es uno mismo' do
      allow_any_instance_of(Access::Grant).to receive(:level).and_call_original # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(Access::Grant).to receive(:level).with(:agenda).and_return('own') # rubocop:disable RSpec/AnyInstance
      post api, params: { title: 'Revisar inventario', unit: 'week', weekdays: [5], starts_on: Date.current, assignee_id: ana.id,
                          time_zone: 'America/Mexico_City' }, headers: beto.create_new_auth_token, as: :json
      expect(response).to have_http_status(:created)
      body = response.parsed_body['task_recurrence']
      expect(body).to include('title' => 'Revisar inventario', 'mine' => true)
      expect(body.dig('assignee', 'id')).to eq(beto.id)

      get api, headers: beto.create_new_auth_token
      expect(response.parsed_body['task_recurrences'].pluck('title')).to eq(['Revisar inventario'])
      get api, params: { scope: 'all' }, headers: ana.create_new_auth_token
      expect(response.parsed_body['task_recurrences'].pluck('title')).to eq(['Revisar inventario'])
    end

    it 'pausar, reanudar y terminar; otro usuario sin acceso no puede tocarla' do
      rec = recurrence(assignee: beto, unit: 'week', weekdays: [1], starts_on: Date.current + 30)
      intruso = create(:user, account: account, role: :agent)
      allow_any_instance_of(Access::Grant).to receive(:level).and_call_original # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(Access::Grant).to receive(:level).with(:agenda).and_return('own') # rubocop:disable RSpec/AnyInstance
      patch "#{api}/#{rec.id}", params: { status: 'paused' }, headers: intruso.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)

      patch "#{api}/#{rec.id}", params: { status: 'paused' }, headers: beto.create_new_auth_token, as: :json
      expect(rec.reload.status).to eq('paused')
      patch "#{api}/#{rec.id}", params: { status: 'active' }, headers: beto.create_new_auth_token, as: :json
      expect(rec.reload).to have_attributes(status: 'active', next_on: rec.cadence.first_on)
      delete "#{api}/#{rec.id}", headers: beto.create_new_auth_token
      expect(rec.reload.status).to eq('ended')
    end

    it 'dentro de un caso: la tarea sale ligada al caso' do
      travel_to(monday.in_time_zone('America/Mexico_City').change(hour: 9)) do
        soporte = CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
        ticket = CaseTicket.create!(account: account, title: 'Grúa 12', contact: contact, case_type: soporte)
        post api, params: { title: 'Revisar inventario', unit: 'day', starts_on: monday, case_ticket_id: ticket.id,
                            assignee_id: ana.id, priority: 'high', time_zone: 'America/Mexico_City' },
                  headers: ana.create_new_auth_token, as: :json
        expect(response).to have_http_status(:created)
        rec = TaskRecurrence.last
        expect(rec).to have_attributes(case_ticket_id: ticket.id, priority: 'high')
        expect(rec.case_tasks.last).to have_attributes(case_ticket_id: ticket.id, title: 'Revisar inventario')
      end
    end

    it 'las estadísticas: a tiempo, tarde, pendientes y no hechas' do
      rec = recurrence(missed_count: 2)
      CaseTask.create!(account: account, title: 'a', task_recurrence: rec, due_at: 1.day.from_now, status: :done, assignee: ana)
      CaseTask.create!(account: account, title: 'b', task_recurrence: rec, due_at: 2.days.ago, status: :done, assignee: ana)
      CaseTask.create!(account: account, title: 'c', task_recurrence: rec, due_at: 1.day.from_now, assignee: ana)
      expect(TaskRecurrences::Serializer.one(rec, ana)[:stats].symbolize_keys).to eq(on_time: 1, late: 1, pending: 1, missed: 2)
    end
  end
end
