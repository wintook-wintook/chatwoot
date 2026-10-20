# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Comercial F3: API de oportunidades.
RSpec.describe 'Case Tickets API — oportunidades' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:base)    { "/api/v1/accounts/#{account.id}/case_tickets" }
  let!(:lost_reason) { CaseOutcomeReason.ensure_defaults_for(account).find_by(outcome: :lost, label: 'Precio') }
  let(:won_reason)       { account.case_outcome_reasons.outcome_won.ordered.first }
  let(:postponed_reason) { account.case_outcome_reasons.outcome_postponed.ordered.first }

  def opportunity(attrs = {})
    CaseTicket.create!({ account: account, title: 'Licencias', contact: contact, case_type: venta,
                         status: :in_progress }.merge(attrs))
  end

  def column(label)
    venta.case_type_columns.find_by!(label: label)
  end

  def patch_json(url, params)
    patch url, params: params, headers: admin.create_new_auth_token, as: :json
  end

  it 'crea con datos comerciales y los expone en el JSON' do
    post base, params: { case_ticket: { contact_id: contact.id, case_type_id: venta.id, title: 'CRM 20 usuarios',
                                        amount: '25000.50', currency: 'usd', expected_close_at: '2026-12-15' } },
               headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    body = response.parsed_body['case_ticket']
    expect(body).to include('is_commercial' => true, 'amount' => 25_000.5, 'currency' => 'USD',
                            'expected_close_at' => '2026-12-15', 'probability' => 10)
  end

  it 'editar el monto deja amount_changed; cerrada ya no se edita' do
    opp = opportunity(amount: 1000)
    patch_json("#{base}/#{opp.id}", case_ticket: { amount: 1800 })
    expect(response).to have_http_status(:ok)
    expect(opp.case_events.last).to have_attributes(event_type: 'amount_changed')
    expect(opp.case_events.last.payload['amount']).to include('to' => '1800.0')

    opp.close_with_outcome!(:won, reason_id: won_reason.id)
    patch_json("#{base}/#{opp.id}", case_ticket: { amount: 1 })
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'no ofrece resolver, cancelar ni cerrar como transición' do
    get "#{base}/#{opportunity.id}", headers: admin.create_new_auth_token
    expect(response.parsed_body['case_ticket']['can_transition_to']).not_to include('resolved', 'cancelled', 'closed')
  end

  describe 'Kanban' do
    it 'soltar en Ganada pide el motivo si hay catálogo de ganadas y luego cierra' do
      opp = opportunity
      patch_json("#{base}/#{opp.id}/move", case_type_column_id: column('Ganada').id)
      expect(response.parsed_body).to include('requires_outcome' => true, 'outcome' => 'won')

      patch_json("#{base}/#{opp.id}/move", case_type_column_id: column('Ganada').id,
                                           closure: { outcome_reason_id: won_reason.id })
      expect(response).to have_http_status(:ok)
      expect(opp.reload).to have_attributes(status: 'closed', outcome: 'won', outcome_reason_id: won_reason.id,
                                            case_type_column_id: column('Ganada').id)
    end

    it 'soltar en Ganada cierra al instante si no hay motivos de ganada activos' do
      account.case_outcome_reasons.outcome_won.update_all(active: false)
      opp = opportunity
      patch_json("#{base}/#{opp.id}/move", case_type_column_id: column('Ganada').id)

      expect(response).to have_http_status(:ok)
      expect(opp.reload.outcome).to eq('won')
    end

    it 'soltar en Perdida pide el motivo y luego cierra' do
      opp = opportunity
      patch_json("#{base}/#{opp.id}/move", case_type_column_id: column('Perdida').id)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to include('requires_outcome' => true, 'outcome' => 'lost')

      patch_json("#{base}/#{opp.id}/move", case_type_column_id: column('Perdida').id,
                                           closure: { outcome_reason_id: lost_reason.id })
      expect(opp.reload).to have_attributes(outcome: 'lost', outcome_reason_id: lost_reason.id)
    end

    it 'de Perdida a Ganada no se pasa arrastrando' do
      opp = opportunity
      opp.close_with_outcome!(:lost, reason_id: lost_reason.id)
      patch_json("#{base}/#{opp.id}/move", case_type_column_id: column('Ganada').id)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(opp.reload.outcome).to eq('lost')
    end

    it 'soltar en Pospuesta pide la fecha' do
      opp = opportunity
      patch_json("#{base}/#{opp.id}/move", case_type_column_id: column('Pospuesta').id)
      expect(response.parsed_body).to include('requires_postpone' => true)

      patch_json("#{base}/#{opp.id}/move", case_type_column_id: column('Pospuesta').id,
                                           postponed_until: 1.month.from_now.to_date.iso8601,
                                           postpone_reason_id: postponed_reason.id)
      expect(opp.reload).to be_postponed
      expect(opp.postpone_reason_id).to eq(postponed_reason.id)
    end
  end

  it 'outcome, postpone y resume por endpoint' do
    opp = opportunity
    patch_json("#{base}/#{opp.id}/postpone", postponed_until: 3.days.from_now.to_date.iso8601)
    expect(response.parsed_body['error']).to match(/motivo de la pospuesta/)

    patch_json("#{base}/#{opp.id}/postpone", postponed_until: 3.days.from_now.to_date.iso8601,
                                             postpone_reason_id: postponed_reason.id)
    expect(response.parsed_body['case_ticket']['is_postponed']).to be(true)
    expect(response.parsed_body['case_ticket']['postpone_reason']).to include('id' => postponed_reason.id)

    patch_json("#{base}/#{opp.id}/resume", {})
    expect(response.parsed_body['case_ticket']['status']).to eq('in_progress')

    patch_json("#{base}/#{opp.id}/outcome", outcome: 'lost', outcome_reason_id: lost_reason.id)
    expect(response.parsed_body['case_ticket']).to include('outcome' => 'lost',
                                                           'outcome_reason' => { 'id' => lost_reason.id, 'label' => 'Precio' })
  end

  it 'filtra por fecha de cierre: solo cerradas, por el día en que se cerraron' do
    open_opp = opportunity
    recent = opportunity
    recent.close_with_outcome!(:won, reason_id: won_reason.id)
    old = opportunity
    old.close_with_outcome!(:won, reason_id: won_reason.id)
    old.update_columns(outcome_at: 2.months.ago, closed_at: 2.months.ago)

    get base, params: { case_class: 'commercial', closed_from: 7.days.ago.to_date.iso8601,
                        closed_to: Date.current.iso8601 }, headers: admin.create_new_auth_token
    ids = response.parsed_body['case_tickets'].pluck('id')
    expect(ids).to include(recent.id)
    expect(ids).not_to include(old.id, open_opp.id)
  end

  it 'el lote no cierra oportunidades (#8)' do
    opp = opportunity(status: :validating)
    post "#{base}/bulk", params: { ids: [opp.id], bulk_action: 'transition', status: 'closed' },
                         headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to include('updated' => 0, 'skipped' => 1)
    expect(opp.reload.status).to eq('validating')
  end

  it 'filtra por clase y resultado' do
    won = opportunity
    won.close_with_outcome!(:won, reason_id: won_reason.id)
    opportunity

    get base, params: { case_class: 'commercial', outcome: 'won' }, headers: admin.create_new_auth_token
    expect(response.parsed_body['case_tickets'].pluck('id')).to eq([won.id])
  end

  it 'las métricas de Tickets solo cuentan Soporte y el embudo tiene su endpoint (F5)' do
    soporte = CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
    CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
    opportunity(amount: 900)

    get "#{base}/metrics", headers: admin.create_new_auth_token
    expect(response.parsed_body['summary']['total']).to eq(1)
    expect(response.parsed_body['by_type'].keys).not_to include('Venta')

    get "/api/v2/accounts/#{account.id}/case_reports/pipeline", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['summary']['open_count']).to eq(1)
  end

  it 'filtra por cierre estimado y pospuestas (E1.1)' do
    nov = opportunity(expected_close_at: Date.new(2026, 11, 20))
    opportunity(expected_close_at: Date.new(2026, 12, 5))
    paused = opportunity
    paused.postpone!(until_date: 1.week.from_now.to_date, reason_id: postponed_reason.id)

    get base, params: { case_class: 'commercial', expected_close_from: '2026-11-01', expected_close_to: '2026-11-30' },
              headers: admin.create_new_auth_token
    expect(response.parsed_body['case_tickets'].pluck('id')).to eq([nov.id])

    get base, params: { case_class: 'commercial', postponed: 'true' }, headers: admin.create_new_auth_token
    expect(response.parsed_body['case_tickets'].pluck('id')).to eq([paused.id])

    # «En curso»: abiertas sin las pospuestas.
    get base, params: { case_class: 'commercial', status: 'pending', postponed: 'false' },
              headers: admin.create_new_auth_token
    expect(response.parsed_body['case_tickets'].pluck('id')).not_to include(paused.id)
    expect(response.parsed_body['case_tickets'].pluck('id')).to include(nov.id)
  end

  it 'las métricas de Soporte se acotan al tipo elegido (E1.1)' do
    soporte = CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
    otro = CaseType.create!(account: account, name: 'Incidente', color: '#ef4444')
    CaseTicket.create!(account: account, title: 'A', contact: contact, case_type: soporte)
    CaseTicket.create!(account: account, title: 'B', contact: contact, case_type: otro)

    get "#{base}/metrics", params: { case_type_id: otro.id }, headers: admin.create_new_auth_token
    expect(response.parsed_body['summary']).to include('total' => 1, 'total_open' => 1)
  end

  it 'el tablero trae abiertas completas y cerradas solo de los últimos N días (E1.3)' do
    open_opp = opportunity
    recent = opportunity
    recent.close_with_outcome!(:won, reason_id: won_reason.id)
    old = opportunity
    old.close_with_outcome!(:won, reason_id: won_reason.id)
    old.update_columns(closed_at: 60.days.ago, updated_at: 60.days.ago) # rubocop:disable Rails/SkipsModelValidations

    get base, params: { case_class: 'commercial', closed_within_days: 30 }, headers: admin.create_new_auth_token
    expect(response.parsed_body['case_tickets'].pluck('id')).to contain_exactly(open_opp.id, recent.id)
  end

  it 'las métricas de Soporte se filtran por responsable y equipo (E1.3)' do
    soporte = CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
    agent = create(:user, account: account)
    CaseTicket.create!(account: account, title: 'A', contact: contact, case_type: soporte, assignee: agent)
    CaseTicket.create!(account: account, title: 'B', contact: contact, case_type: soporte)

    get "#{base}/metrics", params: { assignee_id: agent.id }, headers: admin.create_new_auth_token
    expect(response.parsed_body['summary']).to include('total' => 1, 'total_open' => 1)
  end

  it 'catálogo de motivos y moneda por defecto' do
    get "/api/v1/accounts/#{account.id}/case_outcome_reasons", params: { outcome: 'cancelled' },
                                                               headers: admin.create_new_auth_token
    expect(response.parsed_body['case_outcome_reasons'].pluck('label')).to include('Duplicada')

    patch "/api/v1/accounts/#{account.id}/case_setting", params: { case_setting: { default_currency: 'usd' } },
                                                         headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['default_currency']).to eq('USD')
  end
end
