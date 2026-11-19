# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — el mapa de fuentes: el agente sabe qué hay en cada una para buscar en la que
# corresponde; las hojas en modo «Datos» se buscan exacto; y el entrenador propone corregir el
# «¿Qué hay aquí?» si buscó en la fuente equivocada.
RSpec.describe Motor2::SourceMap, type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let!(:sheet) do
    create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Precios',
                              config: { 'sheet_mode' => 'data' }).tap do |s|
      GoogleSheetRow.create!(account_id: account.id, knowledge_source: s, row_index: 1, data: { 'Servicio' => 'Grúa', 'Precio' => '$1,800' })
    end
  end
  let(:template) do
    create(:tracking_template, account: account, engine: '2', motor2: { 'sources' => ["google_sheet:#{sheet.id}"] })
  end

  before do
    create(:canned_response, account: account, short_code: 'Horario de atención', kind: 'general')
    create(:canned_response, account: account, short_code: 'Ficha Derecho', kind: 'ficha')
  end

  it 'dice qué hay en cada fuente: lo calculado de lo que tiene o su «¿Qué hay aquí?»' do
    entries = described_class.new(account).entries(template.motor2['sources'])
    canned, hoja = entries

    expect(canned).to include(key: 'canned_response', name: 'Respuestas predefinidas')
    expect(canned[:about]).to include('General (1): Horario de atención', 'Fichas (1): Ficha Derecho')
    expect(hoja[:about]).to include('datos exactos', 'Precio', 'Servicio', '1 filas')

    sheet.update!(config: sheet.config.merge('purpose' => 'El precio exacto de cada servicio'))
    expect(described_class.new(account).entries(template.motor2['sources']).last[:about]).to eq('El precio exacto de cada servicio')
  end

  it 'el agente recibe DÓNDE BUSCAR con sus fuentes (y no las que no marcó)' do
    create(:knowledge_source, account: account, source_type: 'google_doc', name: 'Reglamento')
    runner = Motor2::Runner.new(Motor2::Config.new(template), state: Motor2::State.new, history: [])
    system = Motor2::Prompt.new(runner, Motor2::Skills.for(runner)).system

    expect(system).to include('DÓNDE BUSCAR', '- Respuestas predefinidas: General (1)', '- Precios: tabla (datos exactos')
    expect(system).not_to include('Reglamento')
  end

  it 'una hoja en modo «Datos» se busca exacto en sus filas, no por parecido' do
    allow_any_instance_of(SheetQueryService).to receive(:perform).and_return('$1,800') # rubocop:disable RSpec/AnyInstance
    found = Motor2::Search.new(account, ["google_sheet:#{sheet.id}"]).call('¿cuánto cuesta la grúa?', only: 'Precios')

    expect(found.first).to include(fuente: 'Precios', resultados: [include(informacion: include('$1,800'))])
  end

  it 'en Bases de conocimiento se escribe el «¿Qué hay aquí?» de cada fuente' do
    patch "/api/v1/accounts/#{account.id}/knowledge_base/sources/#{sheet.id}/purpose",
          params: { purpose: 'Precio exacto por servicio' }, headers: admin.create_new_auth_token, as: :json
    expect(sheet.reload.config).to include('purpose' => 'Precio exacto por servicio', 'sheet_mode' => 'data')
  end

  it 'el asistente de «Atención a prospectos» guarda las fuentes que marcó (solo las de la cuenta)' do
    inbox = create(:inbox, account: account)
    agent = Motor2::Functions::Form.new(account, { kind: 'prospects', name: 'Prospectos', inbox_ids: [inbox.id], settings: {},
                                                   sources: ["google_sheet:#{sheet.id}", 'google_doc:999999'] }, user: admin).save
    expect(agent.motor2['sources']).to eq(["google_sheet:#{sheet.id}"])
    expect(Motor2::Functions::AgentJson.call(agent)[:sources]).to eq(["google_sheet:#{sheet.id}"])
  end

  it 'el entrenador: si buscó en la fuente equivocada, propone su «¿Qué hay aquí?» y se cambia de un clic' do
    stub_request(:post, %r{api.openai.com/v1/embeddings}).to_return(status: 500)
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    trainer = AgentTester::Trainer.new(template, user: admin)
    allow(trainer).to receive(:chat).and_return('causes' => [{ 'kind' => 'where', 'source' => 'precios', 'text' => 'Precio exacto por servicio' }])
    msg = trainer.call(messages: [{ 'role' => 'user', 'content' => '¿Cuánto la grúa?' }], reply: 'No sé', feedback: '$1,800',
                       trace: { 'engine' => '2' })[:messages].first

    expect(msg).to include(kind: 'where', source: 'Precios', source_id: sheet.id, suggestion: 'Precio exacto por servicio', can_fix: true)
    expect(AgentTestLog.find(msg[:log_id]).kind).to eq('where')

    post "/api/v1/accounts/#{account.id}/agent_tester/fix_purpose", params: { source_id: sheet.id, text: msg[:suggestion] },
                                                                    headers: admin.create_new_auth_token, as: :json
    expect(sheet.reload.config['purpose']).to eq('Precio exacto por servicio')
  end
end
