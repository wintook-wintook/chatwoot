# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — `force: true` en `transition!` habilita el movimiento libre entre
# columnas personalizadas (case_tickets_controller#move_across_state), saltándose la
# validación de "un salto" de VALID_TRANSITIONS. El resto de garantías (documentar
# cierre, timestamps, evento) se mantienen intactas.
RSpec.describe CaseTicket do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:case_type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }

  def crear_ticket(status:)
    described_class.create!(account: account, contact: contact, case_type: case_type, title: 'Caso', status: status)
  end

  describe '#transition!' do
    it 'sin force respeta VALID_TRANSITIONS (comportamiento actual)' do
      ticket = crear_ticket(status: 'open')

      expect { ticket.transition!('resolved') }.to raise_error(/Transición inválida/)
    end

    it 'con force: true salta la validación de un salto' do
      ticket = crear_ticket(status: 'open')

      ticket.transition!('resolved', force: true)

      expect(ticket.reload.status).to eq('resolved')
      expect(ticket.resolved_at).to be_present
    end

    it 'con force: true sigue exigiendo documentar el cierre para llegar a closed' do
      ticket = crear_ticket(status: 'open')

      expect { ticket.transition!('closed', force: true) }.to raise_error(/documentar/)
    end

    it 'con force: true y closure válido, cierra y guarda los datos de cierre' do
      ticket = crear_ticket(status: 'open')

      ticket.transition!('closed', force: true, closure: {
                           closure_type: 'resolved', closure_cause: 'x', closure_solution: 'y'
                         })

      expect(ticket.reload.status).to eq('closed')
      expect(ticket.closure_type).to eq('resolved')
    end
  end
end
