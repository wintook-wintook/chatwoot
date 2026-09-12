# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — filtro de estado "agrupado" en la lista de casos: 'pending'
# y 'closed' cubren varios estados ITIL a la vez, sin romper el filtro por
# estado exacto que ya usaban las vistas guardadas de antes de este cambio.
RSpec.describe 'Case Tickets API — filtro de estado agrupado (pending/closed)' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:case_type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }

  def crear_ticket(status:)
    CaseTicket.create!(account: account, contact: contact, case_type: case_type, title: 'Caso', status: status)
  end

  def listar(status)
    get "/api/v1/accounts/#{account.id}/case_tickets",
        params: { status: status }, headers: admin.create_new_auth_token, as: :json
  end

  it 'status=pending devuelve solo estados activos (no resuelto/validando/cerrado/cancelado)' do
    pendiente = crear_ticket(status: 'escalated')
    crear_ticket(status: 'resolved')
    crear_ticket(status: 'validating')
    crear_ticket(status: 'closed')
    crear_ticket(status: 'cancelled')

    listar('pending')

    ids = response.parsed_body['case_tickets'].pluck('id')
    expect(ids).to eq([pendiente.id])
  end

  it 'status=closed devuelve resuelto, validando, cerrado y cancelado' do
    crear_ticket(status: 'open')
    resuelto = crear_ticket(status: 'resolved')
    validando = crear_ticket(status: 'validating')
    cerrado = crear_ticket(status: 'closed')
    cancelado = crear_ticket(status: 'cancelled')

    listar('closed')

    ids = response.parsed_body['case_tickets'].pluck('id')
    expect(ids).to contain_exactly(resuelto.id, validando.id, cerrado.id, cancelado.id)
  end

  it 'un estado exacto (vista guardada de antes de este cambio) sigue funcionando igual' do
    exacto = crear_ticket(status: 'escalated')
    crear_ticket(status: 'open')

    listar('escalated')

    ids = response.parsed_body['case_tickets'].pluck('id')
    expect(ids).to eq([exacto.id])
  end

  it 'sin status no filtra nada (comportamiento de "Todos")' do
    crear_ticket(status: 'open')
    crear_ticket(status: 'closed')

    get "/api/v1/accounts/#{account.id}/case_tickets", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['case_tickets'].size).to eq(2)
  end
end
