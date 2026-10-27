# frozen_string_literal: true

require 'rails_helper'

# Plan-Contratos R1 — tipos de contrato, contratos del cliente e importación.
RSpec.describe 'Contracts API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let!(:contact) { create(:contact, account: account, name: 'Ana', email: 'ana@example.com', phone_number: '+525512345678') }
  let(:base)    { "/api/v1/accounts/#{account.id}" }
  let!(:iguala) { account.contract_types.create!(name: 'Iguala de soporte', default_every: 1, default_unit: :month) }

  def give_role(user, key)
    role = AccessRole.for_account(account).find { |r| r.key == key }
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  def csv_file(text)
    Rack::Test::UploadedFile.new(StringIO.new(text), 'text/csv', original_filename: 'contratos.csv')
  end

  it 'el administrador da de alta tipos con campos propios; un agente no' do
    params = { contract_type: { name: 'Monitoreo', default_term_months: 12,
                                custom_fields: [{ label: 'Cuenta de monitoreo', type: 'text' }] } }
    post "#{base}/contract_types", params: params, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['contract_type']['custom_fields']).to eq(
      [{ 'key' => 'cuenta_de_monitoreo', 'label' => 'Cuenta de monitoreo', 'type' => 'text' }]
    )

    post "#{base}/contract_types", params: { contract_type: { name: 'Otro' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'alta, lista por estado, registrar pago y cancelar' do
    params = { contract: { contact_id: contact.id, contract_type_id: iguala.id, title: 'Iguala 10 h', price: 3500,
                           starts_on: Date.current - 40.days } }
    post "#{base}/contracts", params: params, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body['contract']['id']
    expect(response.parsed_body['contract']['state']).to eq('overdue')

    get "#{base}/contracts", params: { state: 'overdue' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['contracts'].pluck('id')).to eq([id])
    expect(response.parsed_body['meta']['counts']).to include('overdue' => 1, 'active' => 0)

    post "#{base}/contracts/#{id}/register_payment", headers: admin.create_new_auth_token, as: :json
    post "#{base}/contracts/#{id}/register_payment", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['contract']['state']).to eq('active')

    post "#{base}/contracts/#{id}/cancel", params: { reason: 'Cerró el negocio' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['contract']).to include('state' => 'cancelled', 'cancel_reason' => 'Cerró el negocio')
  end

  it 'sin «Ver montos» no viaja el precio' do
    account.contracts.create!(contact: contact, contract_type: iguala, title: 'Iguala', price: 3500, starts_on: Date.current)
    give_role(agent, 'technician')
    contact.update!(owner_id: agent.id)
    get "#{base}/contracts", params: { contact_id: contact.id }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['contracts'].first).to include('price' => nil, 'amount' => nil)
  end

  it 'importa un CSV por correo o teléfono y reporta las filas con error' do
    csv = <<~CSV
      contacto,tipo,concepto,precio,cada,periodo,inicio,plazo_meses
      ana@example.com,Iguala de soporte,Iguala básica,2500,1,mes,2026-01-15,12
      55 1234 5678,iguala de soporte,Iguala plus,4000,3,meses,15/02/2026,
      nadie@example.com,Iguala de soporte,X,1,1,mes,2026-01-01,
      ana@example.com,No existe,X,1,1,mes,2026-01-01,
    CSV
    post "#{base}/contracts/import", params: { file: csv_file(csv) }, headers: admin.create_new_auth_token

    expect(response.parsed_body).to include('created' => 2, 'updated' => 0)
    expect(response.parsed_body['errors'].pluck('line')).to eq([4, 5])
    plus = account.contracts.find_by(title: 'Iguala plus')
    expect(plus).to have_attributes(contact_id: contact.id, every: 3, unit: 'month', starts_on: Date.new(2026, 2, 15),
                                    term_months: nil)
    expect(account.contracts.find_by(title: 'Iguala básica').ends_on).to eq(Date.new(2027, 1, 15))
  end

  it 'llena los datos propios del tipo con columnas de su nombre' do
    iguala.update!(custom_fields: [{ label: 'Horas incluidas', type: 'number' }])
    csv = "contacto,tipo,concepto,Horas incluidas\nana@example.com,Iguala de soporte,Iguala 10 h,10\n"
    post "#{base}/contracts/import", params: { file: csv_file(csv) }, headers: admin.create_new_auth_token

    expect(account.contracts.last.custom_attributes).to eq('horas_incluidas' => '10')
  end

  it 'con la columna id actualiza en vez de duplicar, y lo vacío no cambia' do
    record = account.contracts.create!(contact: contact, contract_type: iguala, title: 'Iguala', price: 3500,
                                       starts_on: Date.new(2026, 1, 1), quantity: 2)
    csv = "id,contacto,tipo,concepto,cantidad,precio\n#{record.id},,,,,3900\n"
    post "#{base}/contracts/import", params: { file: csv_file(csv) }, headers: admin.create_new_auth_token

    expect(response.parsed_body).to include('created' => 0, 'updated' => 1)
    expect(record.reload).to have_attributes(price: 3900, quantity: 2, title: 'Iguala')
  end
end
