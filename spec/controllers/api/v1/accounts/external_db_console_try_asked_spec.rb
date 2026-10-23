# frozen_string_literal: true

require 'rails_helper'

# proyecto@erp_productos — F4: "Probar como el agente" en la Consola ERP.
RSpec.describe 'External DB Console: try_asked', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:connection) do
    ExternalDbConnection.create!(account: account, name: 'SAE', engine: :firebird, erp_type: :sae, host: 'erp.test',
                                 port: 3050, database: 'db')
  end
  let!(:query) do
    connection.external_db_queries.create!(account: account, name: 'buscar_productos', sql_template: 'SELECT 1 FROM INVE01',
                                           params_schema: ExternalDb::QueryLibrary::PRODUCT_PARAMS)
  end
  let(:asked) { instance_double(ExternalDb::AskedParams) }
  let(:url) { "/api/v1/accounts/#{account.id}/external_db_console/try_asked" }

  before { allow(ExternalDb::AskedParams).to receive(:new).and_return(asked) }

  def try(message)
    post url, params: { query_id: query.id, message: message }, headers: agent.create_new_auth_token, as: :json
  end

  it 'pide a la IA los parámetros de búsqueda y devuelve lo que traería el ERP' do
    allow(asked).to receive(:call).and_return(use: true, params: { 'texto' => 'toshiba' })
    run = instance_double(ExternalDb::AskedRun, call: { columns: ['NOMBRE'], rows: [{ 'NOMBRE' => 'TOSHIBA' }], partial: true })
    allow(ExternalDb::AskedRun).to receive(:new).with(query, { 'texto' => 'toshiba' }).and_return(run)

    try('¿tienen aire toshiba?')

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('use' => true, 'params' => { 'texto' => 'toshiba' }, 'partial' => true,
                                            'row_count' => 1)
    expect(ExternalDb::AskedParams).to have_received(:new)
      .with(query: query, asked: %w[texto precio_min precio_max con_existencia], question: '¿tienen aire toshiba?')
  end

  it 'si el mensaje no pide la consulta, lo dice' do
    allow(asked).to receive(:call).and_return(use: false, params: {})

    try('gracias')
    expect(response.parsed_body).to eq('use' => false, 'params' => {})
  end

  it 'sin respuesta de la IA, un error claro' do
    allow(asked).to receive(:call).and_return(nil)

    try('hola')
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('OpenAI')
  end
end
