# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Comercial F5: métricas del embudo comercial.
RSpec.describe V2::Reports::Cases::PipelineBuilder do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:seller)  { create(:user, account: account, name: 'Vendedora') }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let!(:lost_reason) { CaseOutcomeReason.ensure_defaults_for(account).find_by(outcome: :lost, label: 'Precio') }
  let(:won_reason)       { account.case_outcome_reasons.outcome_won.ordered.first }
  let(:postponed_reason) { account.case_outcome_reasons.outcome_postponed.ordered.first }
  let(:report) { described_class.new(account: account, params: {}).build }

  def opportunity(attrs = {})
    CaseTicket.create!({ account: account, title: 'Opp', contact: contact, case_type: venta, assignee: seller,
                         status: :in_progress }.merge(attrs))
  end

  def column(label)
    venta.case_type_columns.find_by!(label: label)
  end

  before do
    opportunity(amount: 1000, currency: 'MXN', case_type_column_id: column('Propuesta').id,
                expected_close_at: Date.new(2026, 11, 15))
    opportunity(amount: 500, currency: 'USD', case_type_column_id: column('Negociación').id)
    opportunity(amount: 2000, currency: 'MXN').close_with_outcome!(:won, reason_id: won_reason.id)
    opportunity(amount: 300, currency: 'MXN').close_with_outcome!(:lost, reason_id: lost_reason.id)
    # Soporte no entra al embudo.
    CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
  end

  it 'separa lo abierto por moneda con su ponderado' do
    expect(report[:summary][:open_count]).to eq(2)
    expect(report[:summary][:open_value]).to contain_exactly(
      { currency: 'MXN', amount: 1000.0, weighted: 500.0 },
      { currency: 'USD', amount: 500.0, weighted: 375.0 }
    )
  end

  it 'cuenta lo decidido y la tasa de cierre (ganadas / ganadas + perdidas)' do
    expect(report[:summary]).to include(won_count: 1, lost_count: 1, cancelled_count: 0, win_rate: 50)
    expect(report[:summary][:won_value]).to eq([{ currency: 'MXN', amount: 2000.0, count: 1 }])
  end

  it 'agrupa las abiertas por etapa del embudo, en orden' do
    expect(report[:stages].pluck(:label)).to eq(%w[Propuesta Negociación])
  end

  describe 'Plan-Metricas-Comercial' do
    it 'M1 — compara lo decidido con el período anterior de la misma duración' do
      # La ganada del `before` se cerró a la hora REAL: `until` sale de esa hora, no
      # de la fecha fija del travel_to (si no, la prueba falla cualquier otro día).
      real_now = Time.current
      travel_to Time.zone.parse('2026-10-21 12:00') do
        old = opportunity(amount: 900, currency: 'MXN')
        old.close_with_outcome!(:won, reason_id: won_reason.id)
        old.update!(outcome_at: 20.days.ago)
        params = { since: 10.days.ago.to_i.to_s, until: (real_now + 1.day).to_i.to_s }
        built = described_class.new(account: account, params: params).build

        expect(built[:summary][:won_count]).to eq(1)
        expect(built[:previous]).to include(won_count: 1, lost_count: 0)
        expect(built[:previous][:won_value]).to eq([{ currency: 'MXN', amount: 900.0, count: 1 }])
      end
    end

    it 'M1 — compara contra el rango que manda el front (mismo tramo del mes anterior)' do
      travel_to Time.zone.parse('2026-10-21 12:00') do
        sept = opportunity(amount: 300, currency: 'MXN')
        sept.close_with_outcome!(:won, reason_id: won_reason.id)
        sept.update!(outcome_at: Time.zone.parse('2026-09-10 10:00'))
        late = opportunity(amount: 700, currency: 'MXN')
        late.close_with_outcome!(:won, reason_id: won_reason.id)
        late.update!(outcome_at: Time.zone.parse('2026-09-25 10:00'))
        params = { since: Time.zone.parse('2026-10-01').to_i.to_s, until: Time.current.to_i.to_s,
                   prev_since: Time.zone.parse('2026-09-01').to_i.to_s,
                   prev_until: Time.zone.parse('2026-09-21 12:00').to_i.to_s }
        built = described_class.new(account: account, params: params).build

        expect(built[:previous]).to include(won_count: 1)
        expect(built[:previous][:won_value]).to eq([{ currency: 'MXN', amount: 300.0, count: 1 }])
      end
    end

    it 'M1 — sin período no hay comparación' do
      expect(report[:previous]).to be_nil
    end

    it 'M2 — lo que cierra este mes y «Requieren atención» (cierre vencido, mayor monto primero)' do
      travel_to Date.new(2026, 11, 20) do
        opportunity(amount: 50, currency: 'MXN', expected_close_at: Date.new(2026, 11, 1))
        built = described_class.new(account: account, params: {}).build

        expect(built[:summary][:closing_this_month]).to eq([{ currency: 'MXN', amount: 1050.0, weighted: 512.5, count: 2 }])
        expect(built[:attention].pluck(:amount)).to eq([1000.0, 50.0])
        expect(built[:attention].first).to include(stage: 'Propuesta', currency: 'MXN')
      end
    end
  end

  describe 'comprometidas por el cliente' do
    # Miércoles 18 nov 2026: la semana va del 16 al 22.
    let(:today) { Date.new(2026, 11, 18) }

    it 'separa lo comprometido (semana, mes, vencido) de lo probable del mes' do
      travel_to today do
        opportunity(amount: 400, currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 11, 20))
        opportunity(amount: 600, currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 11, 28))
        opportunity(amount: 90, currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 11, 2))
        c = described_class.new(account: account, params: {}).build[:summary][:commitments]

        expect(c[:this_week]).to contain_exactly(include(currency: 'MXN', amount: 400.0, count: 1))
        expect(c[:this_month]).to contain_exactly(include(amount: 1090.0, count: 3))
        expect(c[:overdue]).to contain_exactly(include(amount: 90.0, count: 1))
        # La de 1000 (15 nov, sin compromiso) es lo probable del mes: no cuenta doble.
        expect(c[:probable_this_month]).to eq([{ currency: 'MXN', amount: 1000.0, weighted: 500.0, count: 1 }])
      end
    end

    it 'en «Requieren atención» las promesas vencidas van primero' do
      travel_to today do
        opportunity(amount: 90, currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 11, 2))
        attention = described_class.new(account: account, params: {}).build[:attention]

        expect(attention.map { |r| [r[:amount], r[:reason]] })
          .to eq([[90.0, 'promise_overdue'], [1000.0, 'close_overdue']])
      end
    end

    it 'el pronóstico trae la parte comprometida y «Esta semana» filtra la semana' do
      travel_to today do
        opportunity(amount: 400, currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 11, 20))
        built = described_class.new(account: account, params: {}).build
        november = built[:forecast].find { |r| r[:month] == '2026-11' && r[:currency] == 'MXN' }
        week = described_class.new(account: account, params: { close: 'this_week' }).build

        expect(november).to include(amount: 1400.0, committed: 400.0)
        expect(week[:summary][:open_count]).to eq(1)
      end
    end

    it 'promesas cumplidas: ganadas a tiempo y sin mover la fecha' do
      travel_to today do
        kept = opportunity(amount: 100, currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 11, 20))
        kept.close_with_outcome!(:won, reason_id: won_reason.id)
        late = opportunity(amount: 100, currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 11, 10))
        late.close_with_outcome!(:won, reason_id: won_reason.id)
        moved = opportunity(amount: 100, currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 11, 15))
        changes = moved.assign_commercial_data(expected_close_at: '2026-11-25')
        moved.save!
        moved.log_commercial_change!(changes)
        moved.close_with_outcome!(:won, reason_id: won_reason.id)
        opportunity(currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 11, 20))
          .close_with_outcome!(:lost, reason_id: lost_reason.id)

        summary = described_class.new(account: account, params: {}).build[:summary]
        expect(summary).to include(promises_decided: 4, promises_kept: 1, promises_rate: 25)
      end
    end
  end

  describe 'pestaña Embudo' do
    def build(params)
      described_class.new(account: account, params: params).build
    end

    it 'marca la etapa en espera (Pospuesta) para ponerla aparte' do
      opportunity(amount: 50, currency: 'MXN', status: :waiting_on_customer, case_type_column_id: column('Pospuesta').id)
      waiting = report[:stages].to_h { |s| [s[:label], s[:waiting]] }
      expect(waiting).to include('Propuesta' => false, 'Negociación' => false, 'Pospuesta' => true)
    end

    it 'lista las monedas y filtra todo por una' do
      expect(report[:currencies]).to eq(%w[MXN USD])
      mxn = build(currency: 'mxn')
      expect(mxn[:stages].pluck(:label)).to eq(%w[Propuesta])
      expect(mxn[:summary]).to include(won_count: 1, lost_count: 1)
      expect(mxn[:currencies]).to eq(%w[MXN USD])
    end

    it 'acota lo abierto por cierre estimado, sin tocar lo decidido' do
      travel_to Date.new(2026, 11, 3) do
        expect(build(close: 'this_month')[:stages].pluck(:label)).to eq(%w[Propuesta])
        expect(build(close: 'none')[:stages].pluck(:label)).to eq(%w[Negociación])
        expect(build(close: 'overdue')[:stages]).to be_empty
        expect(build(close: 'this_month')[:summary][:won_count]).to eq(1)
      end
    end

    it 'trae el monto de las canceladas' do
      opportunity(amount: 80, currency: 'MXN').close_with_outcome!(:cancelled, reason_id: account.case_outcome_reasons.outcome_cancelled.first&.id)
      expect(report[:summary][:cancelled_value]).to eq([{ currency: 'MXN', amount: 80.0, count: 1 }])
    end
  end

  it 'motivos, vendedor y pronóstico' do
    expect(report[:loss_reasons]).to eq([{ outcome: 'lost', label: 'Precio', count: 1,
                                           values: [{ currency: 'MXN', amount: 300.0, count: 1 }] }])
    expect(report[:by_assignee].first).to include(assignee_name: 'Vendedora', open_count: 2, won_count: 1, win_rate: 50)
    expect(report[:forecast]).to eq([{ currency: 'MXN', amount: 1000.0, weighted: 500.0, count: 1, month: '2026-11',
                                       committed: 0.0 }])
  end

  it 'cuenta como recuperada una ganada que antes se había perdido' do
    opp = opportunity(amount: 100, currency: 'MXN')
    opp.close_with_outcome!(:lost, reason_id: lost_reason.id)
    opp.reopen!(reason: 'Volvió')
    opp.close_with_outcome!(:won, reason_id: won_reason.id)

    expect(report[:summary][:recovered_count]).to eq(1)
  end

  it 'el resto de los reportes de casos ya lee el resultado real' do
    buckets = V2::Reports::Cases::DistributionBuilder.new(account: account, params: { case_type_id: venta.id }).outcome
    expect(buckets).to include(open: 2, won: 1, lost: 1)
  end

  it 'scopes de clase: una oportunidad no cae en non_commercial y un caso sin tipo sí' do
    sin_tipo = CaseTicket.create!(account: account, title: 'Sin tipo', contact: contact)
    expect(account.case_tickets.non_commercial).to include(sin_tipo)
    expect(account.case_tickets.non_commercial.where(case_type: venta)).to be_empty
    expect(account.case_tickets.of_class('support')).to include(sin_tipo)
    expect(account.case_tickets.commercial.count).to eq(4)
  end
end
