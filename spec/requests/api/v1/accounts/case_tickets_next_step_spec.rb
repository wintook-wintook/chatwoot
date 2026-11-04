# frozen_string_literal: true

require 'rails_helper'

# La lista y el tablero dicen el siguiente paso de cada caso abierto (su tarea pendiente o
# tarea agendada más próxima) y marcan los que se quedaron sin continuidad.
RSpec.describe 'Case tickets: siguiente paso' do
  let(:account) { create(:account) }
  let!(:with_steps) { ticket('Con pasos') }
  let!(:overdue) { ticket('Vencido') }
  let!(:empty) { ticket('Sin nada') }
  let!(:closed) { ticket('Cerrado') }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:api)     { "/api/v1/accounts/#{account.id}/case_tickets" }

  def ticket(title)
    CaseTicket.create!(account: account, title: title, contact: contact, case_type: soporte, assignee: admin)
  end

  def list(params = {})
    get api, params: params, headers: admin.create_new_auth_token
    response.parsed_body['case_tickets'].index_by { |t| t['title'] }
  end

  before do
    CaseTask.create!(account: account, case_ticket: with_steps, title: 'Llamar', assignee: admin, due_at: 1.day.from_now)
    CaseMeeting.create!(account: account, case_ticket: with_steps, title: 'Visita', organizer: admin,
                        starts_at: 3.days.from_now, ends_at: 3.days.from_now + 1.hour)
    CaseTask.create!(account: account, case_ticket: overdue, title: 'Atrasada', assignee: admin, due_at: 2.days.ago)
    CaseTask.create!(account: account, case_ticket: empty, title: 'Hecha', assignee: admin, status: :done)
    CaseTask.create!(account: account, contact: contact, title: 'Suelta sin caso', assignee: admin)
    closed.update_columns(status: CaseTicket.statuses[:closed]) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'trae lo más próximo, si está vencido, cuántos más, y «none» cuando no hay nada' do
    rows = list

    expect(rows['Con pasos']['next_step']).to include('kind' => 'task', 'overdue' => false, 'more' => 1)
    expect(rows['Vencido']['next_step']).to include('kind' => 'task', 'overdue' => true, 'more' => 0)
    expect(rows['Sin nada']['next_step']).to eq('kind' => 'none')
    expect(rows['Cerrado']['next_step']).to be_nil
  end

  it 'filtra los abiertos sin siguiente paso (aunque haya tareas sueltas sin caso)' do
    expect(list(next_step: 'none').keys).to eq(['Sin nada'])
  end

  it 'el detalle no lo trae (solo la lista y el tablero)' do
    get "#{api}/#{empty.id}", headers: admin.create_new_auth_token

    expect(response.parsed_body['case_ticket']).not_to have_key('next_step')
  end
end
