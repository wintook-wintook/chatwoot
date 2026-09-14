# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — movimiento libre entre columnas personalizadas: el orden de
# columnas que configuró el admin manda, independientemente de si el status destino
# era alcanzable en un salto de VALID_TRANSITIONS. Excepciones: un caso cancelado
# nunca cambia de status, y aterrizar en `closed` sigue exigiendo documentar el cierre.
RSpec.describe 'Case Tickets API — PATCH /move (columnas personalizadas)' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:case_type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }

  # Columnas sin relación de "un salto" entre sí, a propósito: para probar el
  # movimiento libre hace falta un tipo cuyas columnas NO reflejen VALID_TRANSITIONS.
  let(:col_res) do
    CaseTypeColumn.create!(account: account, case_type: case_type, label: 'Resuelto', position: 0, statuses: %w[resolved validating])
  end
  let(:col_closed) { CaseTypeColumn.create!(account: account, case_type: case_type, label: 'Cerrado', position: 1, statuses: %w[closed cancelled]) }
  let(:col_satisf) { CaseTypeColumn.create!(account: account, case_type: case_type, label: 'Satisfacción', position: 2, statuses: %w[closed]) }

  def crear_ticket(status:)
    CaseTicket.create!(account: account, contact: contact, case_type: case_type, title: 'Caso', status: status)
  end

  def mover(ticket, column, closure: nil)
    body = { case_type_column_id: column.id }
    body[:closure] = closure if closure
    patch "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/move",
          params: body, headers: admin.create_new_auth_token, as: :json
  end

  it 'mueve el ticket saltando etapas aunque no sea un salto válido de VALID_TRANSITIONS' do
    ticket = crear_ticket(status: 'escalated') # escalated → resolved NO es un salto directo

    mover(ticket, col_res)

    expect(response).to have_http_status(:ok)
    ticket.reload
    expect(ticket.status).to eq('resolved')
    expect(ticket.case_type_column_id).to eq(col_res.id)
  end

  it 'un caso cancelado no puede cambiar de status vía columna (rama B)' do
    ticket = crear_ticket(status: 'cancelled')

    mover(ticket, col_satisf) # satisfacción solo cubre closed, no cancelled

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to match(/cancelado/i)
    expect(ticket.reload.status).to eq('cancelled')
  end

  it 'un caso cancelado sí puede mover el puntero entre columnas que ya cubren cancelled (rama A)' do
    otra_col_cerrado = CaseTypeColumn.create!(account: account, case_type: case_type, label: 'Cerrado B', position: 5, statuses: %w[cancelled])
    ticket = crear_ticket(status: 'cancelled')
    ticket.update_column(:case_type_column_id, col_closed.id) # rubocop:disable Rails/SkipsModelValidations

    mover(ticket, otra_col_cerrado)

    expect(response).to have_http_status(:ok)
    ticket.reload
    expect(ticket.status).to eq('cancelled') # el status NO cambia
    expect(ticket.case_type_column_id).to eq(otra_col_cerrado.id)
  end

  it 'aterrizar en closed sin datos de cierre se rechaza con requires_closure' do
    ticket = crear_ticket(status: 'resolved')

    mover(ticket, col_satisf)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['requires_closure']).to be(true)
    expect(ticket.reload.status).to eq('resolved') # no se mutó nada
  end

  it 'aterrizar en closed CON datos de cierre sí cierra el caso y fija la columna' do
    ticket = crear_ticket(status: 'resolved')

    mover(ticket, col_satisf, closure: { closure_type: 'resolved', closure_cause: 'x', closure_solution: 'y' })

    expect(response).to have_http_status(:ok)
    ticket.reload
    expect(ticket.status).to eq('closed')
    expect(ticket.case_type_column_id).to eq(col_satisf.id)
    expect(ticket.closure_cause).to eq('x')
  end
end
