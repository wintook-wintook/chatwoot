# frozen_string_literal: true

require 'rails_helper'

# Cobranza: la cartera por cortes (Excel/CSV hoy; los sistemas administrativos después, con el mismo corte).
RSpec.describe 'Collections API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Ana Admin') }
  let(:agent_user) { create(:user, account: account, role: :agent) }
  let(:api) { "/api/v1/accounts/#{account.id}/collections" }
  let(:headers) { admin.create_new_auth_token }

  let(:csv1) do
    <<~CSV
      Clave cliente;Cliente;RFC;Contacto;WhatsApp;Correo;Folio;Fecha factura;Vencimiento;Total;Saldo;Moneda
      C-1;Grúas del Norte;GNO120304AB1;Laura;8112345678;;A-1;01/10/2026;31/10/2026;15000;15000;MXN
      C-1;Grúas del Norte;GNO120304AB1;Laura;8112345678;;A-2;15/10/2026;14/12/2026;8500;3500;
      C-2;Taller Ruiz;;Jorge;;jorge@ruiz.mx;B-9;;19/11/2026;4200;4200;MXN
      ;Sin datos;;;;;X;;;;;
    CSV
  end

  def upload(content, path = 'imports', name: 'cartera.csv', mapping: nil)
    file = Rack::Test::UploadedFile.new(StringIO.new(content), 'text/csv', original_filename: name)
    post "#{api}/#{path}", params: { file: file, mapping: mapping }.compact, headers: headers
    response.parsed_body
  end

  # Un .xlsx mínimo de verdad (ZIP sin compresión con su XML), para probar el lector sin gemas.
  def xlsx(rows)
    shared = rows.flatten.uniq
    cells = rows.each_with_index.map do |row, r|
      xml_cells = row.each_with_index.map { |v, c| %(<c r="#{('A'.ord + c).chr}#{r + 1}" t="s"><v>#{shared.index(v)}</v></c>) }.join
      %(<row r="#{r + 1}">#{xml_cells}</row>)
    end.join
    files = { 'xl/sharedStrings.xml' => %(<sst xmlns="x">#{shared.map { |v| "<si><t>#{v}</t></si>" }.join}</sst>),
              'xl/worksheets/sheet1.xml' => %(<worksheet xmlns="x"><sheetData>#{cells}</sheetData></worksheet>) }
    stored_zip(files)
  end

  def stored_zip(files)
    data = ''.b
    central = ''.b
    files.each do |name, body|
      offset = data.bytesize
      data << zip_local(name, body.b)
      central << zip_central(name, body.b, offset)
    end
    data << central << ['PK'.b, 5, 6, 0, 0, files.size, files.size, central.bytesize, data.bytesize - central.bytesize, 0]
                       .pack('a2CCvvvvVVv')
  end

  def zip_local(name, body)
    ['PK'.b, 3, 4, 20, 0, 0, 0, 0, Zlib.crc32(body), body.bytesize, body.bytesize, name.bytesize, 0].pack('a2CCvvvvvVVVvv') + name + body
  end

  def zip_central(name, body, offset)
    ['PK'.b, 1, 2, 20, 20, 0, 0, 0, 0, Zlib.crc32(body), body.bytesize, body.bytesize, name.bytesize, 0, 0, 0, 0, 0, offset]
      .pack('a2CCvvvvvvVVVvvvvvVV') + name
  end

  it 'la plantilla trae las columnas del layout' do
    get "#{api}/template", headers: headers
    expect(response.body).to include('Clave cliente,Cliente,RFC,Contacto,WhatsApp,Correo,Folio,Fecha factura,Vencimiento')
  end

  it 'solo administradores' do
    get "#{api}/overview", headers: agent_user.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
  end

  it 'vista previa: reconoce las columnas, avisa las filas con error y no guarda nada' do
    data = upload(csv1, 'preview')
    expect(data['mapping']).to include('customer_key' => 'Clave cliente', 'balance' => 'Saldo', 'due_on' => 'Vencimiento')
    expect(data['preview']).to include('valid' => 3, 'customers' => 2, 'invoices' => 3, 'totals' => { 'MXN' => 22_700.0 })
    expect(data['preview']['errors'].first['reason']).to include('falta')
    expect(data['preview']['diff']).to include('new' => 3)
    expect(account.receivables.count).to eq(0)
  end

  it 'cada corte reemplaza al anterior: abonos, pagadas (ya no vienen) y nuevas; liga al cliente por su WhatsApp' do
    laura = create(:contact, account: account, name: 'Laura', phone_number: '+528112345678')
    upload(csv1)
    expect(account.receivables.pluck(:folio)).to contain_exactly('A-1', 'A-2', 'B-9')
    expect(account.receivable_customers.find_by(external_key: 'clave:C-1')).to have_attributes(link_status: 'linked', contact_id: laura.id)

    data = upload("Clave cliente;Cliente;Folio;Vencimiento;Saldo\nC-1;Grúas del Norte;A-2;14/12/2026;1000\nC-2;Taller Ruiz;B-9;19/11/2026;4200\n")
    expect(data['stats']['diff']).to include('paid' => 1, 'paid_amount' => 15_000.0, 'payment' => 1, 'payment_amount' => 2500.0)
    expect(account.receivables.find_by(folio: 'A-1').status).to eq('paid')
    expect(account.receivables.find_by(folio: 'A-2').balance).to eq(1000)
  end

  it 'su propio Excel (.xlsx) con otras columnas: elige cuál es cuál una vez y se recuerda' do
    content = xlsx([%w[Num Razón Doc Vence Debe Cel], ['77', 'Taller Ruiz', 'F-1', '30/12/2026', '999.50', '3331234567']])
    mapping = { customer_key: 'Num', customer_name: 'Razón', folio: 'Doc', due_on: 'Vence', balance: 'Debe', phone: 'Cel' }
    upload(content, name: 'mio.xlsx', mapping: mapping)
    expect(account.receivables.first).to have_attributes(folio: 'F-1', balance: 999.5, due_on: Date.new(2026, 12, 30))

    data = upload(content, 'preview', name: 'mio.xlsx')
    expect(data['mapping']).to include('balance' => 'Debe', 'folio' => 'Doc')
  end

  it 'por ligar: crear organización y contacto con los datos de la cartera, o ignorar' do
    upload(csv1)
    get "#{api}/customers", params: { filter: 'pending' }, headers: headers
    expect(response.parsed_body['total']).to eq(2)

    post "#{api}/customers/create_pending", headers: headers
    expect(response.parsed_body['pending']).to eq(0)
    gruas = account.receivable_customers.find_by(external_key: 'clave:C-1')
    expect(gruas.organization).to have_attributes(name: 'Grúas del Norte', tax_id: 'GNO120304AB1', stage: 'customer')
    expect(gruas.contact).to have_attributes(phone_number: '+528112345678')
  end

  it 'un «ya pagué» rechazado vuelve a cobrarse' do
    upload(csv1)
    customer = account.receivable_customers.find_by(external_key: 'clave:C-2')
    customer.receivables.update_all(claimed_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    claim = customer.payment_claims.create!(account: account, note: 'Pagué por transferencia')
    post "#{api}/claims/#{claim.id}/review", params: { decision: 'reject', note: 'No llegó' }, headers: headers
    expect(claim.reload.status).to eq('rejected')
    expect(customer.receivables.collectable.count).to eq(1)
  end
end
