# Todo este spec pisa `created_at` de tickets/eventos ya creados para simular
# timestamps separados en el historial — real solo sirve para probar la reconstrucción
# de checkpoints, no las reglas de negocio de transition!/validaciones del modelo.
# rubocop:disable Rails/SkipsModelValidations
require 'rails_helper'

RSpec.describe V2::Reports::Cases::StageDurationBuilder do
  subject(:builder) { described_class.new(account: account, params: params) }

  let(:account)   { create(:account) }
  let(:contact)   { create(:contact, account: account) }
  let(:agent)     { create(:user, account: account, role: :agent, name: 'Vendedor Uno') }
  let(:case_type) { CaseType.create!(account: account, name: 'Comercial', color: '#3b82f6') }
  let(:params)    { {} }

  def crear_ticket(**attrs)
    CaseTicket.create!({ account: account, contact: contact, case_type: case_type, title: 'Oportunidad' }.merge(attrs))
  end

  # Recorre transiciones REALES (transition!, no update_columns) para que
  # case_events se pueble tal cual en producción, y después corre el reloj hacia
  # atrás en los eventos ya creados — así el checkpoint builder ve timestamps
  # reales y separados, sin depender de gems de time-travel no instaladas acá.
  def transicionar_con_offsets(ticket, transiciones)
    transiciones.each { |status, extra| ticket.transition!(status, actor: agent, **extra) }
    base = ticket.created_at
    eventos = ticket.case_events.order(:created_at).to_a
    offsets = (0..transiciones.size).to_a
    eventos.each_with_index { |evento, i| evento.update_columns(created_at: base + offsets[i].days) }
    ticket.update_columns(created_at: base)
  end

  describe '#velocity' do
    it 'promedia el tiempo en cada status, solo sobre intervalos ya cerrados' do
      ticket = crear_ticket(assignee: agent)
      transicionar_con_offsets(ticket, [
                                 ['classified', {}],
                                 ['assigned', {}],
                                 ['in_progress', {}],
                                 ['resolved', {}],
                                 ['closed', { closure: { closure_type: 'resolved', closure_cause: 'x', closure_solution: 'y' } }]
                               ])

      result = builder.velocity

      expect(result.find { |r| r[:status] == 'open' }).to include(avg_days: 1.0, count: 1)
      expect(result.find { |r| r[:status] == 'in_progress' }).to include(avg_days: 1.0, count: 1)
      expect(result.find { |r| r[:status] == 'resolved' }).to include(avg_days: 1.0, count: 1)
    end

    it 'no incluye el status actual (todavía en curso, sin checkpoint siguiente)' do
      ticket = crear_ticket(assignee: agent)
      transicionar_con_offsets(ticket, [['classified', {}]])

      result = builder.velocity

      expect(result.find { |r| r[:status] == 'classified' }).to be_nil
      expect(result.find { |r| r[:status] == 'open' }).to include(count: 1)
    end

    it 'un ticket que nunca transicionó no aporta ningún intervalo cerrado' do
      crear_ticket(assignee: agent)

      expect(builder.velocity).to eq([])
    end

    it 'promedia entre varios tickets que pasaron por el mismo status' do
      t1 = crear_ticket(assignee: agent)
      transicionar_con_offsets(t1, [['classified', {}]]) # 1 día en open

      t2 = crear_ticket(assignee: agent)
      transicionar_con_offsets(t2, [['classified', {}]])
      # Alargamos el open de t2 a 3 días en vez de 1, reescribiendo su único checkpoint posterior.
      evento = t2.case_events.order(:created_at).last
      evento.update_columns(created_at: t2.created_at + 3.days)

      result = builder.velocity

      expect(result.find { |r| r[:status] == 'open' }).to include(avg_days: 2.0, count: 2)
    end
  end

  describe '#stalled' do
    it 'lista tickets abiertos cuyo tiempo en el status actual supera el umbral' do
      ticket = crear_ticket(assignee: agent)
      ticket.update_columns(created_at: 5.days.ago)

      rows = builder.stalled(threshold_days: 3)

      expect(rows.pluck(:id)).to include(ticket.id)
      expect(rows.find { |r| r[:id] == ticket.id }[:stalled_days]).to be_within(0.1).of(5.0)
    end

    it 'no incluye tickets por debajo del umbral' do
      crear_ticket(assignee: agent) # recién creado

      expect(builder.stalled(threshold_days: 3)).to eq([])
    end

    it 'no incluye tickets cerrados ni cancelados, aunque lleven mucho tiempo así' do
      cerrado = crear_ticket(assignee: agent)
      cerrado.update_columns(status: CaseTicket.statuses['closed'], created_at: 30.days.ago)
      cancelado = crear_ticket(assignee: agent)
      cancelado.update_columns(status: CaseTicket.statuses['cancelled'], created_at: 30.days.ago)

      rows = builder.stalled(threshold_days: 3)

      expect(rows.pluck(:id)).not_to include(cerrado.id, cancelado.id)
    end

    it 'mide desde el último cambio de status, no desde la creación' do
      ticket = crear_ticket(assignee: agent)
      ticket.update_columns(created_at: 10.days.ago)
      ticket.transition!('classified', actor: agent)
      ticket.case_events.order(:created_at).last.update_columns(created_at: 1.day.ago)

      rows = builder.stalled(threshold_days: 3)

      expect(rows.pluck(:id)).not_to include(ticket.id)
    end

    it 'incluye folio, título y vendedor para que la lista sea accionable' do
      ticket = crear_ticket(assignee: agent, title: 'Oportunidad estancada')
      ticket.update_columns(created_at: 5.days.ago)

      row = builder.stalled(threshold_days: 3).find { |r| r[:id] == ticket.id }

      expect(row[:title]).to eq('Oportunidad estancada')
      expect(row[:assignee_name]).to eq('Vendedor Uno')
      expect(row[:folio]).to be_present
    end

    it 'respeta los filtros comunes (case_type_id)' do
      otro_tipo = CaseType.create!(account: account, name: 'Soporte', color: '#ef4444')
      ticket = crear_ticket(assignee: agent, case_type: otro_tipo)
      ticket.update_columns(created_at: 10.days.ago)

      scoped = described_class.new(account: account, params: { case_type_id: case_type.id })

      expect(scoped.stalled(threshold_days: 3)).to eq([])
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
