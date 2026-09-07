require 'rails_helper'

RSpec.describe V2::Reports::Cases::AssigneeSummaryBuilder do
  subject(:builder) { described_class.new(account: account, params: params) }

  let(:account)   { create(:account) }
  let(:contact)   { create(:contact, account: account) }
  let(:agent)     { create(:user, account: account, role: :agent, name: 'Vendedor Uno') }
  let(:otro_agente) { create(:user, account: account, role: :agent, name: 'Vendedor Dos') }
  let(:case_type) { CaseType.create!(account: account, name: 'Comercial', color: '#3b82f6') }
  let(:params)    { {} }

  def crear_ticket(**attrs)
    CaseTicket.create!({ account: account, contact: contact, case_type: case_type, title: 'Oportunidad' }.merge(attrs))
  end

  # Igual que en outcome/timeseries specs: se pisa directo el estado ya resuelto
  # (transition!/close! disparan reglas de negocio que no vienen al caso acá).
  # rubocop:disable Rails/SkipsModelValidations
  def cerrar(ticket, closure_type:, created_at: nil, closed_at: nil)
    attrs = { status: CaseTicket.statuses['closed'], closure_type: CaseTicket.closure_types[closure_type] }
    attrs[:created_at] = created_at if created_at
    attrs[:closed_at] = closed_at if closed_at
    ticket.update_columns(attrs)
  end
  # rubocop:enable Rails/SkipsModelValidations

  describe '#build' do
    it 'agrupa por assignee_id, separando ganados/perdidos/abiertos/otro cierre' do
      cerrar(crear_ticket(assignee: agent), closure_type: 'resolved')
      cerrar(crear_ticket(assignee: agent), closure_type: 'cancelled')
      crear_ticket(assignee: agent) # abierto

      row = builder.build.find { |r| r[:assignee_id] == agent.id }

      expect(row).to include(won: 1, lost: 1, open: 1, other_closed: 0, conversion_rate: 50)
    end

    it 'incluye el nombre del vendedor' do
      crear_ticket(assignee: agent)

      row = builder.build.find { |r| r[:assignee_id] == agent.id }

      expect(row[:assignee_name]).to eq('Vendedor Uno')
    end

    it 'agrupa los tickets sin asignar bajo assignee_id nil' do
      crear_ticket(assignee: nil)

      row = builder.build.find { |r| r[:assignee_id].nil? }

      expect(row[:open]).to eq(1)
      expect(row[:assignee_name]).to be_nil
    end

    it 'conversion_rate es nil sin ganados ni perdidos (nada decidido todavía)' do
      crear_ticket(assignee: agent)

      row = builder.build.find { |r| r[:assignee_id] == agent.id }

      expect(row[:conversion_rate]).to be_nil
    end

    it 'calcula el promedio de días hasta el cierre solo sobre tickets con closed_at' do
      cerrar(crear_ticket(assignee: agent), closure_type: 'resolved', created_at: 5.days.ago, closed_at: 2.days.ago)
      cerrar(crear_ticket(assignee: agent), closure_type: 'cancelled', created_at: 3.days.ago, closed_at: 1.day.ago)

      row = builder.build.find { |r| r[:assignee_id] == agent.id }

      expect(row[:avg_close_days]).to eq(2.5)
    end

    it 'un ticket perdido directo (status cancelled, sin closed_at) no distorsiona el promedio' do
      cerrar(crear_ticket(assignee: agent), closure_type: 'resolved', created_at: 5.days.ago, closed_at: 2.days.ago)
      # rubocop:disable Rails/SkipsModelValidations
      crear_ticket(assignee: agent).update_columns(status: CaseTicket.statuses['cancelled'])
      # rubocop:enable Rails/SkipsModelValidations

      row = builder.build.find { |r| r[:assignee_id] == agent.id }

      expect(row[:lost]).to eq(1)
      expect(row[:avg_close_days]).to eq(3.0)
    end

    it 'ordena por ganados descendente, y por abiertos como desempate' do
      cerrar(crear_ticket(assignee: agent), closure_type: 'resolved')
      crear_ticket(assignee: otro_agente)
      crear_ticket(assignee: otro_agente)

      ranking = builder.build.pluck(:assignee_id)

      expect(ranking.first).to eq(agent.id)
    end

    it 'respeta los filtros comunes (case_type_id)' do
      otro_tipo = CaseType.create!(account: account, name: 'Soporte', color: '#ef4444')
      crear_ticket(assignee: agent, case_type: otro_tipo)

      scoped = described_class.new(account: account, params: { case_type_id: case_type.id })

      expect(scoped.build).to be_empty
    end
  end
end
