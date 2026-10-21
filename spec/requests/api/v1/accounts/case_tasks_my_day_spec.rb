# frozen_string_literal: true

require 'rails_helper'

# Plan-Bandeja-Prioridad F1 — «Mi día»: pendientes del agente por puntaje, con
# motivos, la agenda de hoy y la carga del día.
RSpec.describe 'Case Tasks Index API — Mi día' do
  let(:account) { create(:account) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:other)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:case_type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, contact: contact, case_type: case_type, title: 'Caso') }

  def tarea(title, **attrs)
    CaseTask.create!({ account: account, case_ticket: ticket, title: title, assignee: agent }.merge(attrs))
  end

  def mi_dia(params = {})
    get "/api/v1/accounts/#{account.id}/case_tasks",
        params: { mode: 'my_day', assignee_id: agent.id }.merge(params),
        headers: agent.create_new_auth_token, as: :json
    response.parsed_body
  end

  it 'ordena por puntaje, con motivos, y deja fuera hechas y ajenas' do
    tarea('Sin fecha', priority: :low)
    tarea('Vencida urgente', priority: :urgent, due_at: 2.days.ago)
    tarea('Hoy', priority: :medium, due_at: 1.hour.from_now)
    tarea('Hecha', due_at: 3.days.ago, status: :done)
    tarea('De otro', assignee: other, due_at: 3.days.ago)

    body = mi_dia

    expect(response).to have_http_status(:ok)
    titles = body['case_tasks'].pluck('title')
    expect(titles).to eq(['Vencida urgente', 'Hoy', 'Sin fecha'])
    first = body['case_tasks'].first
    expect(first['score']).to be > body['case_tasks'].second['score']
    expect(first['reasons'].pluck('key')).to include('overdue', 'priority_urgent')
  end

  it 'trae la agenda de hoy y la carga del día (vencidas + hoy)' do
    tarea('Vencida', due_at: 1.day.ago, estimated_minutes: 60)
    tarea('Hoy', due_at: 1.hour.from_now)
    tarea('Mañana', due_at: 1.day.from_now + 2.hours, estimated_minutes: 30)
    CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Arranque', organizer: agent,
                        starts_at: Time.zone.now.end_of_day - 1.hour, ends_at: Time.zone.now.end_of_day - 30.minutes)
    CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Otro día', organizer: agent,
                        starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)

    body = mi_dia

    expect(body['meta']['agenda'].pluck('title')).to eq(['Arranque'])
    expect(body['meta']['load']).to include('count' => 2, 'minutes' => 60, 'unestimated' => 1)
  end

  describe 'F2 — orden propio' do
    let(:today) { Time.zone.today.iso8601 }

    def guardar_plan(ids, day: today)
      put "/api/v1/accounts/#{account.id}/case_tasks/my_day_plan",
          params: { day: day, task_ids: ids }, headers: agent.create_new_auth_token, as: :json
      response.parsed_body
    end

    it 'el plan va primero, en el orden del agente; el resto sigue por puntaje' do
      urgente = tarea('Urgente', priority: :urgent, due_at: 2.days.ago)
      baja = tarea('Baja', priority: :low)
      media = tarea('Media', priority: :medium, due_at: 1.hour.from_now)

      guardar_plan([baja.id, media.id])
      body = mi_dia(day: today)

      expect(body['case_tasks'].pluck('title')).to eq(%w[Baja Media Urgente])
      expect(body['case_tasks'].pluck('planned')).to eq([true, true, false])
      expect(body['meta']['plan_count']).to eq(2)
      expect(urgente.reload.planned_on).to be_nil
    end

    it 'reemplaza el plan: lo que ya no viene sale; ignora ajenas y hechas' do
      a = tarea('A')
      b = tarea('B')
      ajena = tarea('Ajena', assignee: other)
      hecha = tarea('Hecha', status: :done)

      guardar_plan([a.id, b.id])
      body = guardar_plan([b.id, ajena.id, hecha.id])

      expect(body['task_ids']).to eq([b.id])
      expect(a.reload.planned_on).to be_nil
      expect(b.reload).to have_attributes(planned_on: Time.zone.today, focus_position: 0)
    end

    it 'el plan es del día: otro día no aparece' do
      a = tarea('A')
      guardar_plan([a.id])
      a.update!(planned_on: Time.zone.today - 1)

      expect(mi_dia(day: today)['case_tasks'].first['planned']).to be(false)
    end

    it '«Programada para» hoy desde el formulario entra al orden (al final); después no aparece; lo pasado vuelve' do
      fijada = tarea('Fijada')
      guardar_plan([fijada.id])
      del_form = tarea('Del formulario', planned_on: Time.zone.today)
      despues = tarea('Después', planned_on: Time.zone.today + 3)
      ayer = tarea('Ayer', planned_on: Time.zone.today - 1)

      body = mi_dia(day: today)

      expect(body['case_tasks'].pluck('title')).to eq(['Fijada', 'Del formulario', 'Ayer'])
      expect(body['meta']).to include('later_count' => 1, 'missed' => [ayer.id], 'plan_count' => 2)
      expect(body['case_tasks'].last['reasons'].pluck('key')).to include('planned_missed')
      expect(body['case_tasks'].last['planned_on']).to eq((Time.zone.today - 1).iso8601)
      expect([del_form.id, despues.id]).to all(be_a(Integer))
    end

    it 'guarda «Programada para» desde el formulario de la tarea' do
      url = "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/tasks"
      post url, params: { case_task: { title: 'Plan', planned_on: '2026-11-02' } }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['case_task']['planned_on']).to eq('2026-11-02')
    end

    it 'avisa de las urgentes que llegan después de armar el plan' do
      vieja = tarea('Vieja urgente', priority: :urgent, due_at: 2.days.ago)
      plan = tarea('En plan')
      guardar_plan([plan.id])
      travel 1.minute do
        nueva = tarea('Nueva urgente', priority: :urgent, due_at: 2.days.ago)

        expect(mi_dia(day: today)['meta']['new_urgent']).to eq([nueva.id])
      end
      expect(vieja.reload.planned_on).to be_nil
    end
  end

  it 'sin mode no agrega puntaje ni agenda (la bandeja de siempre)' do
    tarea('Una', due_at: 1.day.ago)

    body = mi_dia(mode: nil)

    expect(body['case_tasks'].first).not_to have_key('score')
    expect(body['meta']).not_to have_key('agenda')
  end

  it 'guarda la duración estimada y la valida' do
    url = "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/tasks"
    post url, params: { case_task: { title: 'Con duración', estimated_minutes: 45 } }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['case_task']['estimated_minutes']).to eq(45)

    post url, params: { case_task: { title: 'Mal', estimated_minutes: 5000 } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
