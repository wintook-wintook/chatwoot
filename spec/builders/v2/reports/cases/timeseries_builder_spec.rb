require 'rails_helper'

RSpec.describe V2::Reports::Cases::TimeseriesBuilder do
  subject(:builder) { described_class.new(account: account, params: params) }

  let(:account)    { create(:account) }
  let(:contact)    { create(:contact, account: account) }
  let(:case_type)  { CaseType.create!(account: account, name: 'Comercial', color: '#3b82f6') }
  let(:current_time) { '26.10.2020 10:00'.to_datetime }

  let(:params) do
    {
      group_by: 'day',
      since: (current_time - 2.days).beginning_of_day.to_i.to_s,
      until: current_time.end_of_day.to_i.to_s
    }
  end

  def crear_ticket(created_at:)
    travel_to(created_at) do
      CaseTicket.create!(account: account, contact: contact, case_type: case_type, title: 'Oportunidad')
    end
  end

  # `closed_at` no se puede fijar en la creación (antes de la validación de cierre) —
  # se pisa directo, igual que en el spec de #outcome.
  # rubocop:disable Rails/SkipsModelValidations
  def cerrar(ticket, closed_at:)
    ticket.update_columns(status: CaseTicket.statuses['closed'], closure_type: CaseTicket.closure_types['resolved'], closed_at: closed_at)
  end
  # rubocop:enable Rails/SkipsModelValidations

  before { travel_to(current_time) }

  describe '#timeseries' do
    it 'agrupa "created" por created_at, independiente de "closed"' do
      crear_ticket(created_at: current_time)
      crear_ticket(created_at: current_time - 1.day)

      result = builder.timeseries

      created_today = result[:created].find { |p| p[:timestamp] == current_time.beginning_of_day.to_i }
      created_yesterday = result[:created].find { |p| p[:timestamp] == (current_time - 1.day).beginning_of_day.to_i }
      expect(created_today[:value]).to eq(1)
      expect(created_yesterday[:value]).to eq(1)
    end

    it 'agrupa "closed" por closed_at, aunque el ticket se haya creado en otro día' do
      ticket = crear_ticket(created_at: current_time - 2.days)
      cerrar(ticket, closed_at: current_time)

      result = builder.timeseries

      closed_today = result[:closed].find { |p| p[:timestamp] == current_time.beginning_of_day.to_i }
      expect(closed_today[:value]).to eq(1)
    end

    it 'no cuenta como "closed" un ticket sin closed_at' do
      crear_ticket(created_at: current_time)

      result = builder.timeseries

      expect(result[:closed].sum { |p| p[:value] }).to eq(0)
    end

    it 'respeta los filtros comunes (case_type_id)' do
      otro_tipo = CaseType.create!(account: account, name: 'Soporte', color: '#ef4444')
      travel_to(current_time) { CaseTicket.create!(account: account, contact: contact, case_type: otro_tipo, title: 'Otro') }
      crear_ticket(created_at: current_time)

      scoped = described_class.new(account: account, params: params.merge(case_type_id: case_type.id))
      result = scoped.timeseries

      expect(result[:created].sum { |p| p[:value] }).to eq(1)
    end

    it 'funciona sin since/until (sin rango, agrupa lo que haya)' do
      crear_ticket(created_at: current_time)

      scoped = described_class.new(account: account, params: { group_by: 'day' })

      expect { scoped.timeseries }.not_to raise_error
    end
  end
end
