# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — la API de la ficha.
RSpec.describe 'Ficha del Agente IA API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/tracking_templates" }
  let!(:hoja) { create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Precios') }
  let(:items) { [{ key: "google_sheet:#{hoja.id}" }] }

  before do
    GoogleSheetRow.create!(account: account, knowledge_source: hoja, row_index: 0, data: { 'Producto' => 'Grúa', 'Precio' => '1800' })
  end

  it 'solo administradores' do
    get "#{base}/ficha_catalog", headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end

  it 'catálogo → vista previa → crear, en unos cuantos clics' do
    get "#{base}/ficha_catalog", headers: admin.create_new_auth_token
    expect(response.parsed_body['cards'].pluck('key')).to include("google_sheet:#{hoja.id}")

    post "#{base}/ficha_preview", params: { name: 'Ventas', items: items }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['validation']['valid']).to be(true)
    expect(response.parsed_body['offers'].first).to include('key' => "google_sheet:#{hoja.id}", 'on' => true)

    expect do
      post "#{base}/ficha_create", params: { name: 'Ventas', items: items }, headers: admin.create_new_auth_token, as: :json
    end.to change(account.tracking_templates, :count).by(1)
    creado = account.tracking_templates.find(response.parsed_body['id'])
    expect(creado.complementary_prompt).to include('{{hoja_buscar: Precios')
    expect(creado.resources['items']).to eq([{ 'key' => "google_sheet:#{hoja.id}" }])
  end

  it 'al crear acepta archivos por subir (ya mencionados en el Entrenamiento) y el nombre que ve el cliente' do
    post "#{base}/ficha_create", params: { name: 'Ventas', items: items, files: [{ name: 'catalogo-2026' }, { name: 'mal nombre' }],
                                           customer_display_name: 'Sofía' },
                                 headers: admin.create_new_auth_token, as: :json

    creado = account.tracking_templates.find(response.parsed_body['id'])
    expect(creado.complementary_prompt).to include('{{catalogo-2026}}').and include('[ARCHIVOS]')
    expect(creado.complementary_prompt).not_to include('mal nombre')
    expect(creado.customer_display_name).to eq('Sofía')
  end

  it '✨ propone objetivo y contexto; sin OpenAI dice por qué' do
    allow(ContactTrackings::Ficha::Suggester).to receive(:new).and_return(
      instance_double(ContactTrackings::Ficha::Suggester, call: { objective: 'Atender', ai_context: 'Grúas', missing: [] })
    )
    post "#{base}/ficha_suggest", params: { name: 'Ventas', items: items }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to eq('objective' => 'Atender', 'ai_context' => 'Grúas', 'missing' => [])

    allow(ContactTrackings::Ficha::Suggester).to receive(:new).and_return(instance_double(ContactTrackings::Ficha::Suggester, call: nil))
    post "#{base}/ficha_suggest", params: { name: 'Ventas', items: items }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'probar va a segundo plano y el resultado se consulta' do
    post "#{base}/ficha_test", params: { name: 'Ventas', items: items, turn_id: 'ficha-abc123' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:accepted)
    expect(ContactTrackings::Ficha::TestJob).to have_been_enqueued.with(account.id, admin.id, 'ficha-abc123', hash_including('name' => 'Ventas'))

    get "#{base}/ficha_test/ficha-abc123", headers: admin.create_new_auth_token
    expect(response.parsed_body['done']).to be(false)
    ContactTrackings::Assistant::TurnProgress.store_result(account, admin, 'ficha-abc123', { passed: 2, total: 2 })
    get "#{base}/ficha_test/ficha-abc123", headers: admin.create_new_auth_token
    expect(response.parsed_body).to eq('done' => true, 'result' => { 'passed' => 2, 'total' => 2 })
  end

  it 'la vista previa dice si está listo; crear con activate deja la automatización' do
    bandeja = create(:inbox, account: account)
    post "#{base}/ficha_preview", params: { name: 'Ventas', items: items, inbox_id: bandeja.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['readiness'].pluck('key')).to include('openai', 'channel', 'context', 'assignment')

    post "#{base}/ficha_create", params: { name: 'Ventas', items: items, inbox_id: bandeja.id, activate: true },
                                 headers: admin.create_new_auth_token, as: :json
    creado = account.tracking_templates.find(response.parsed_body['id'])
    expect(account.automation_rules.last.actions.first['action_params']).to eq([creado.id])
  end

  it 'activar un agente que ya existe; sin canal dice por qué' do
    sin_canal = create(:tracking_template, account: account, inbox: nil)
    post "#{base}/#{sin_canal.id}/ficha/activate", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:unprocessable_entity)

    con_canal = create(:tracking_template, account: account, inbox: create(:inbox, account: account))
    post "#{base}/#{con_canal.id}/ficha/activate", headers: admin.create_new_auth_token
    expect(response.parsed_body['rule']['name']).to include(con_canal.name)
    expect(response.parsed_body['readiness'].find { |i| i['key'] == 'assignment' }['status']).to eq('ok')
  end

  it 'probar un agente que ya existe y sumar una frase a una de sus rutas' do
    template = create(:tracking_template, account: account, complementary_prompt: "@ruta(info #info: pregunta algo): @buscar_articulo\n")
    post "#{base}/#{template.id}/ficha/test", params: { turn_id: 'ficha-existe1' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:accepted)
    expect(ContactTrackings::Ficha::TestJob).to have_been_enqueued.with(account.id, admin.id, 'ficha-existe1', { 'template_id' => template.id })

    post "#{base}/#{template.id}/ficha/apply", params: { phrases: { info: ['¿abren hoy?'] } }, headers: admin.create_new_auth_token, as: :json
    expect(template.reload.complementary_prompt).to include('@ruta(info #info: pregunta algo, ¿abren hoy?): @buscar_articulo')
  end

  it 'la Agenda se guarda al crear y con la ficha (solo calendarios de agendas marcadas)' do
    integracion = UserCalendarIntegration.create!(account: account, user: admin, google_email: 'a@x.com',
                                                  tokens: { 'access_token' => 't', 'refresh_token' => 'r' })
    agenda = { calendar_event_duration: 60, timezone: 'America/Mexico_City', slots_presentation: 'simple',
               booking_calendar_ids: { integracion.id.to_s => ['citas@group'], '999' => ['ajeno'] } }
    post "#{base}/ficha_create", params: { name: 'Citas', items: items + [{ key: "calendar:#{integracion.id}" }], agenda: agenda },
                                 headers: admin.create_new_auth_token, as: :json
    creado = account.tracking_templates.find(response.parsed_body['id'])
    expect(creado).to have_attributes(calendar_event_duration: 60, timezone: 'America/Mexico_City', slots_presentation: 'simple',
                                      calendar_integration_ids: [integracion.id])
    expect(creado.booking_calendar_ids).to eq(integracion.id.to_s => ['citas@group'])

    patch "#{base}/#{creado.id}/ficha", params: { items: items, agenda: { calendar_event_duration: 30 } },
                                        headers: admin.create_new_auth_token, as: :json
    expect(creado.reload.calendar_event_duration).to eq(30)
    expect(response.parsed_body['agenda']['calendar_event_duration']).to eq(30)
  end

  it 'al crear guarda el seguimiento, la bienvenida y la regla de cada archivo' do
    post "#{base}/ficha_create", params: { name: 'Ventas', items: items, retry_interval_value: 2, retry_interval_unit: 'hours', attempts: 4,
                                           whatsapp_templates: [], email_signature: '', welcome: '¡Hola!',
                                           files: [{ name: 'catalogo', ask: false, welcome: true, attempts: [2] },
                                                   { name: 'garantia', ask: true, welcome: false, attempts: [] }] },
                                 headers: admin.create_new_auth_token, as: :json
    creado = account.tracking_templates.find(response.parsed_body['id'])

    expect(creado).to have_attributes(retry_interval_value: 2, retry_interval_unit: 'hours', follow_up_attempts: 4)
    expect(creado.file_rules['catalogo']).to include('ask' => false, 'welcome' => true, 'attempts' => [2])
    expect(creado.file_rules['garantia']).to include('ask' => true, 'welcome' => false, 'attempts' => [])
    expect(ContactTrackings::WelcomeMessage.text(creado.complementary_prompt)).to eq("¡Hola!\n{{catalogo}}")
    expect(creado.complementary_prompt).to include('{{garantia}} en mi respuesta')
    expect(creado.complementary_prompt).not_to include('{{catalogo}} en mi respuesta')
  end

  it '✨ bienvenida: manda el modo y regresa el texto' do
    sugeridor = instance_double(ContactTrackings::Ficha::Suggester)
    allow(ContactTrackings::Ficha::Suggester).to receive(:new).and_return(sugeridor)
    allow(sugeridor).to receive(:call).with(:welcome).and_return(welcome: '¡Hola!')
    post "#{base}/ficha_suggest", params: { name: 'Ventas', items: items, field: 'welcome' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to eq('welcome' => '¡Hola!')
  end

  it 'en un agente existente: la regla «con la bienvenida» se detecta y se aplica' do
    prompt = "@ruta(info #info: pregunta algo): @buscar_articulo\n\n[MENSAJE DE BIENVENIDA]\n¡Hola!"
    template = create(:tracking_template, account: account, complementary_prompt: prompt)
    patch "#{base}/#{template.id}/ficha", params: { items: items, file_rules: { catalogo: { ask: false, welcome: true, attempts: [1] } } },
                                          headers: admin.create_new_auth_token, as: :json
    expect(template.reload.file_rules['catalogo']).to include('ask' => false, 'welcome' => true, 'attempts' => [1])
    expect(response.parsed_body['changes']['added'].pluck('key')).to include('welcome_file:catalogo')

    post "#{base}/#{template.id}/ficha/apply", params: { add: ['welcome_file:catalogo'] }, headers: admin.create_new_auth_token, as: :json
    expect(ContactTrackings::WelcomeMessage.text(template.reload.complementary_prompt)).to eq("¡Hola!\n{{catalogo}}")
    expect(response.parsed_body['changes']['added'].pluck('key')).not_to include('welcome_file:catalogo')
  end

  it 'muestra lo que contiene una hoja' do
    get "#{base}/ficha_sheet/#{hoja.id}", headers: admin.create_new_auth_token
    cuerpo = response.parsed_body
    expect(cuerpo['columns']).to contain_exactly('Producto', 'Precio')
    expect(cuerpo['columns'].zip(cuerpo['rows'].first).to_h).to eq('Producto' => 'Grúa', 'Precio' => '1800')
  end

  it 'las Reglas se guardan al crear y con la ficha' do
    regla = { keyword: 'asesor', action: ContactTrackings::KeywordActionService::VALID_ACTIONS.first,
              direction: ContactTrackings::KeywordActionService::VALID_DIRECTIONS.first }
    post "#{base}/ficha_create", params: { name: 'Ventas', items: items, keyword_actions: [regla] },
                                 headers: admin.create_new_auth_token, as: :json
    creado = account.tracking_templates.find(response.parsed_body['id'])
    expect(creado.keyword_actions.first['keyword']).to eq('asesor')

    patch "#{base}/#{creado.id}/ficha", params: { items: items, keyword_actions: [] }, headers: admin.create_new_auth_token, as: :json
    expect(creado.reload.keyword_actions).to eq([])
    expect(response.parsed_body['keyword_actions']).to eq([])
  end

  it 'guarda la ficha de un agente, dice los cambios y los aplica' do
    template = create(:tracking_template, account: account, complementary_prompt: "@ruta(info #info: pregunta algo): @buscar_articulo\n")

    patch "#{base}/#{template.id}/ficha", params: { items: items }, headers: admin.create_new_auth_token, as: :json
    cambios = response.parsed_body['changes']
    expect(cambios['added'].pluck('key')).to eq(["google_sheet:#{hoja.id}"])

    post "#{base}/#{template.id}/ficha/apply", params: { add: ["google_sheet:#{hoja.id}"] },
                                               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(template.reload.complementary_prompt).to include('{{hoja_buscar: Precios')
    expect(response.parsed_body['changes']['added']).to eq([])
  end
end
