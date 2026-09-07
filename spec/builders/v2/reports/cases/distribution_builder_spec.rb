require 'rails_helper'

RSpec.describe V2::Reports::Cases::DistributionBuilder do
  subject(:builder) { described_class.new(account: account, params: params) }

  let(:account)  { create(:account) }
  let(:contact)  { create(:contact, account: account) }
  let(:agent)    { create(:user, account: account, role: :agent) }
  let(:case_type) { CaseType.create!(account: account, name: 'Comercial', color: '#3b82f6') }

  def crear_ticket(**attrs)
    CaseTicket.create!({ account: account, contact: contact, case_type: case_type, title: 'Oportunidad' }.merge(attrs))
  end

  describe '#funnel' do
    context 'without case_type_id (agrupa por status canónico)' do
      let(:params) { {} }

      before { crear_ticket }

      it 'incluye los 13 status con su conteo, aunque estén en 0' do
        result = builder.funnel

        expect(result.size).to eq(CaseTicket.statuses.size)
        expect(result.find { |r| r[:id] == 'open' }[:count]).to eq(1)
        expect(result.find { |r| r[:id] == 'closed' }[:count]).to eq(0)
      end
    end

    context 'with case_type_id (agrupa por columna del Kanban de ese tipo)' do
      let(:params) { { case_type_id: case_type.id } }
      let(:columns) { case_type.case_type_columns.ordered }

      it 'devuelve las columnas seedeadas por defecto, ordenadas, en 0 sin tickets' do
        result = builder.funnel

        expect(result.pluck(:id)).to eq(columns.pluck(:id))
        expect(result).to all(include(count: 0))
      end

      it 'cuenta un ticket en la columna que tiene asignada' do
        columna_nuevo = columns.first
        crear_ticket(case_type_column: columna_nuevo)

        result = builder.funnel

        expect(result.find { |r| r[:id] == columna_nuevo.id }[:count]).to eq(1)
      end

      it 'agrega un bucket "sin columna" (id/label nil) para tickets sin case_type_column_id' do
        crear_ticket # sin case_type_column: nunca se asigna solo al crear

        result = builder.funnel

        sin_columna = result.last
        expect(sin_columna[:id]).to be_nil
        expect(sin_columna[:label]).to be_nil
        expect(sin_columna[:count]).to eq(1)
      end

      it 'no agrega el bucket "sin columna" si no hay tickets sin asignar' do
        crear_ticket(case_type_column: columns.first)

        result = builder.funnel

        expect(result.pluck(:id)).not_to include(nil)
      end

      it 'filtra por assignee_id' do
        crear_ticket(case_type_column: columns.first, assignee: agent)
        crear_ticket(case_type_column: columns.first)

        scoped = described_class.new(account: account, params: params.merge(assignee_id: agent.id))

        expect(scoped.funnel.find { |r| r[:id] == columns.first.id }[:count]).to eq(1)
      end

      it 'no mezcla tickets de otro tipo de caso' do
        otro_tipo = CaseType.create!(account: account, name: 'Soporte', color: '#ef4444')
        crear_ticket(case_type: otro_tipo, case_type_column: otro_tipo.case_type_columns.ordered.first)

        result = builder.funnel

        expect(result.sum { |r| r[:count] }).to eq(0)
      end
    end
  end

  describe '#outcome' do
    let(:params) { {} }

    # `transition!`/`close!` disparan reglas de negocio (VALID_TRANSITIONS, SLA, folio...)
    # que no vienen al caso acá — solo nos interesa cómo el builder bucketiza status +
    # closure_type ya guardados, así que los pisamos directo con update_columns.
    # rubocop:disable Rails/SkipsModelValidations
    def cerrar(ticket, closure_type:)
      ticket.update_columns(status: CaseTicket.statuses['closed'], closure_type: CaseTicket.closure_types[closure_type])
    end

    def forzar_status(ticket, status)
      ticket.update_columns(status: CaseTicket.statuses[status])
    end
    # rubocop:enable Rails/SkipsModelValidations

    it 'cuenta como abierto cualquier status que no sea closed ni cancelled' do
      crear_ticket # status: open por defecto
      forzar_status(crear_ticket, 'resolved')

      expect(builder.outcome).to eq(open: 2, won: 0, lost: 0, other_closed: 0)
    end

    it 'cuenta como ganado un ticket cerrado con closure_type resolved' do
      cerrar(crear_ticket, closure_type: 'resolved')

      expect(builder.outcome).to eq(open: 0, won: 1, lost: 0, other_closed: 0)
    end

    it 'cuenta como perdido un ticket cerrado con closure_type cancelled' do
      cerrar(crear_ticket, closure_type: 'cancelled')

      expect(builder.outcome).to eq(open: 0, won: 0, lost: 1, other_closed: 0)
    end

    it 'cuenta como perdido un ticket con status cancelled directo, sin closure_type (nunca llegó a closed)' do
      forzar_status(crear_ticket, 'cancelled')

      expect(builder.outcome).to eq(open: 0, won: 0, lost: 1, other_closed: 0)
    end

    it 'cuenta como other_closed un ticket cerrado por duplicado o no aplica' do
      cerrar(crear_ticket, closure_type: 'duplicate')
      cerrar(crear_ticket, closure_type: 'not_applicable')

      expect(builder.outcome).to eq(open: 0, won: 0, lost: 0, other_closed: 2)
    end

    it 'respeta los filtros comunes (case_type_id, assignee_id, etc.)' do
      otro_tipo = CaseType.create!(account: account, name: 'Soporte', color: '#ef4444')
      cerrar(crear_ticket, closure_type: 'resolved')
      cerrar(crear_ticket(case_type: otro_tipo), closure_type: 'resolved')

      scoped = described_class.new(account: account, params: { case_type_id: case_type.id })

      expect(scoped.outcome).to eq(open: 0, won: 1, lost: 0, other_closed: 0)
    end
  end
end
