# frozen_string_literal: true

require 'rails_helper'

# Plan-Bandeja-Prioridad F4 — «Plan de mi día» con IA. La llamada a OpenAI se
# simula (`chat`): aquí se prueba qué se le manda y cómo se limpia la respuesta.
RSpec.describe 'Case Tasks Index API — Plan de mi día (IA)' do
  let(:account) { create(:account) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:other)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:case_type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, contact: contact, case_type: case_type, title: 'Caso') }
  let!(:urgente) { CaseTask.create!(account: account, case_ticket: ticket, title: 'Urgente', assignee: agent, priority: :urgent, due_at: 1.day.ago) }
  let!(:baja) { CaseTask.create!(account: account, case_ticket: ticket, title: 'Baja', assignee: agent, priority: :low, estimated_minutes: 45) }
  let!(:ajena) { CaseTask.create!(account: account, case_ticket: ticket, title: 'Ajena', assignee: other) }

  def pedir_plan
    post "/api/v1/accounts/#{account.id}/case_tasks/my_day_ai",
         params: { day: Time.zone.today.iso8601, tz: 'America/Mexico_City' }, headers: agent.create_new_auth_token, as: :json
    response.parsed_body
  end

  context 'when la IA está activa' do
    before do
      CaseAiConfig.for_account(account).update!(enabled: true)
      allow_any_instance_of(Cases::Ai::DayPlanner).to receive(:available?).and_return(true) # rubocop:disable RSpec/AnyInstance
    end

    it 'manda «Mi día» en orden (solo las del agente) y limpia la respuesta' do
      sent = nil
      allow_any_instance_of(Cases::Ai::DayPlanner).to receive(:chat) do |_planner, **args| # rubocop:disable RSpec/AnyInstance
        sent = args[:user]
        { 'intro' => 'Empieza por lo vencido.',
          'steps' => [{ 'task_id' => urgente.id, 'when' => '9:00', 'note' => 'Vencida' },
                      { 'task_id' => ajena.id, 'when' => '10:00', 'note' => 'no es suya' },
                      { 'task_id' => 999_999, 'when' => '11:00', 'note' => 'inventada' }],
          'later' => [{ 'task_id' => urgente.id, 'note' => 'repetida' }, { 'task_id' => baja.id, 'note' => 'Puede esperar' }],
          'warning' => '' }
      end

      body = pedir_plan

      expect(response).to have_http_status(:ok)
      expect(sent.index('Urgente')).to be < sent.index('Baja')
      expect(sent).not_to include('Ajena')
      expect(sent).to include('duración 45 min')
      plan = body['plan']
      expect(plan['steps'].pluck('task_id')).to eq([urgente.id])
      expect(plan['later']).to eq([{ 'task_id' => baja.id, 'note' => 'Puede esperar' }])
      expect(plan['warning']).to be_nil
    end

    it 'si la IA falla, responde error' do
      allow_any_instance_of(Cases::Ai::DayPlanner).to receive(:chat).and_return(nil) # rubocop:disable RSpec/AnyInstance
      pedir_plan
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it 'apagada para la cuenta → error claro' do
    body = pedir_plan
    expect(response).to have_http_status(:unprocessable_entity)
    expect(body['error']).to include('desactivada')
  end

  it 'sin integración de OpenAI → error claro' do
    CaseAiConfig.for_account(account).update!(enabled: true)
    body = pedir_plan
    expect(body['error']).to include('OpenAI')
  end
end
