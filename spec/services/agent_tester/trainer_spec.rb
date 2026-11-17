# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — el entrenador dice de quién es el error y no cambia nada solo.
RSpec.describe AgentTester::Trainer do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:v1) { create(:tracking_template, account: account, complementary_prompt: "[ROL]\nAtiendes alumnos.") }
  let(:v2) { create(:tracking_template, account: account, engine: '2', motor2: { 'instructions' => 'Atiendes alumnos.' }) }
  let(:turns) { [{ 'role' => 'user', 'content' => '¿Becas?' }, { 'role' => 'assistant', 'content' => '20% y 35%' }] }

  def correct(template, data)
    trainer = described_class.new(template, user: user)
    allow(trainer).to receive(:chat).and_return(data)
    trainer.call(messages: turns, reply: '20% y 35%', feedback: 'Solo la de 20% primero', trace: { 'engine' => template.engine })
  end

  before do
    stub_request(:post, %r{api.openai.com/v1/embeddings}).to_return(status: 500)
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  it 'prompt de un 1.0: dice dónde y qué pegar, sin tocar su Entrenamiento, y queda en la bitácora' do
    result = correct(v1, 'causes' => [{ 'kind' => 'prompt', 'where' => '[ROL]', 'text' => 'Da una beca a la vez.' }])
    msg = result[:messages].first
    expect(msg).to include(kind: 'prompt', where: '[ROL]', suggestion: 'Da una beca a la vez.', engine: '1')
    expect(v1.reload.complementary_prompt).to eq("[ROL]\nAtiendes alumnos.")
    expect(AgentTestLog.find(msg[:log_id])).to have_attributes(kind: 'prompt', engine: '1', feedback: 'Solo la de 20% primero')
  end

  it 'prompt de un 2.0: no lo aplica solo; lo aplica el usuario con «Aplicar»' do
    result = correct(v2, 'causes' => [{ 'kind' => 'prompt', 'field' => 'instructions', 'find' => '', 'text' => 'Da una beca a la vez.' }])
    msg = result[:messages].first
    expect(v2.reload.motor2['instructions']).to eq('Atiendes alumnos.')
    expect(AgentTestLog.find(msg[:log_id]).diagnosis['cause']).to include('field' => 'instructions', 'replace' => 'Da una beca a la vez.')
  end

  it 'contenido: lo que dice la fuente y, si es predefinida, se puede corregir' do
    canned = create(:canned_response, account: account, short_code: 'becas', content: 'Becas de 20% y 35%')
    msg = correct(v1, 'causes' => [{ 'kind' => 'content', 'source' => 'Respuestas predefinidas', 'item' => 'becas',
                                     'found' => 'Becas de 20% y 35%', 'should' => 'Beca de 20%' }])[:messages].first
    expect(msg).to include(kind: 'content', can_fix: true, canned_id: canned.id)
  end

  it 'modelo: solo si cita lo que no siguió; dice dónde cambiarlo según el motor' do
    msg = correct(v1, 'causes' => [{ 'kind' => 'model', 'quote' => 'Atiendes alumnos', 'why' => 'no lo siguió' }])[:messages].first
    expect(msg[:text]).to include('Es del modelo', 'Bot de seguimientos')
  end

  it 'modelo sin cita textual del prompt: no se acepta; se trata como falta de indicación (con la suya, no la queja)' do
    msg = correct(v1, 'causes' => [{ 'kind' => 'model', 'quote' => 'Pregunta siempre el nombre de la empresa', 'why' => 'x',
                                     'where' => '[ROL]', 'text' => 'Da primero solo la beca de 20%.' }])[:messages].first
    expect(msg).to include(kind: 'prompt', where: '[ROL]', suggestion: 'Da primero solo la beca de 20%.')
  end

  it 'modelo sin cita ni indicación: la redacta desde lo esperado, no copia la queja' do
    trainer = described_class.new(v1, user: user)
    allow(trainer).to receive(:chat).and_return({ 'causes' => [{ 'kind' => 'model', 'quote' => 'no está', 'why' => 'x' }] },
                                                { 'text' => 'Cuando pregunten por becas, da primero solo la de 20%.' })
    msg = trainer.call(messages: turns, reply: '20% y 35%', feedback: 'Solo la de 20% primero', trace: { 'engine' => '1' })[:messages].first
    expect(msg).to include(kind: 'prompt', suggestion: 'Cuando pregunten por becas, da primero solo la de 20%.')
  end

  it 'prompt y modelo a la vez sin evidencia: queda solo el de prompt' do
    result = correct(v1, 'causes' => [{ 'kind' => 'prompt', 'where' => '[ROL]', 'text' => 'Una beca a la vez.' },
                                      { 'kind' => 'model', 'quote' => 'algo que no está', 'why' => 'x' }])
    expect(result[:messages].pluck(:kind)).to eq(['prompt'])
  end

  it 'búsqueda (1.0): el dato está pero no llegó; dice cuál, qué llegó (de la traza) y qué agregarle; liga la prueba' do
    canned = create(:canned_response, account: account, short_code: 'Formas de titulación', content: '1. Tesis')
    trainer = described_class.new(v1, user: user)
    allow(trainer).to receive(:embed).and_return(nil)
    allow(trainer).to receive(:chat).and_return('causes' => [{ 'kind' => 'search', 'item' => 'Formas de titulación',
                                                               'arrived' => ['Cédula: texto largo'], 'text' => '¿Cómo me titulo?' }])
    result = trainer.call(messages: turns, reply: '10 formas', feedback: 'Dar la lista',
                          trace: { 'engine' => '1', 'fragmentos' => [{ 'titulo' => 'Cédula' }] })
    msg = result[:messages].first
    expect(msg).to include(kind: 'search', item: 'Formas de titulación', arrived: ['Cédula'], add: '¿Cómo me titulo?',
                           canned_id: canned.id)
    log = AgentTestLog.find(msg[:log_id])
    expect(log).to have_attributes(status: 'pending', agent_test_case_id: AgentTestCase.last.id)
    expect(log.diagnosis['text']).to include('Es de la búsqueda')
  end

  it 'probar de nuevo: al terminar la corrida, la corrección queda «passed» o «failing» con lo que contestó' do
    trainer = described_class.new(v1, user: user)
    allow(trainer).to receive(:chat).and_return('causes' => [{ 'kind' => 'prompt', 'where' => '[ROL]', 'text' => 'Lista.' }])
    log = AgentTestLog.find(trainer.call(messages: turns, reply: 'x', feedback: 'En lista', trace: { 'engine' => '1' })[:messages].first[:log_id])
    test_case = log.agent_test_case
    run = test_case.batch.runs.create!(account: account, tracking_template: v1, total: 1, case_ids: [test_case.id], status: 'done',
                                       results: [{ 'case_id' => test_case.id, 'ok' => true, 'reply' => '1. A', 'reason' => 'Cumple' }])
    log.update!(status: 'retesting', retest: { 'run_id' => run.id })
    AgentTestLog.finish_retests(run)
    expect(log.reload).to have_attributes(status: 'passed')
    expect(log.retest).to include('reply' => '1. A', 'reason' => 'Cumple')
  end

  it 'cada 👎 revisado queda solo como prueba en el lote del agente y del día, sin repetirse' do
    data = { 'causes' => [{ 'kind' => 'prompt', 'where' => '[ROL]', 'text' => 'Una beca a la vez.' }] }
    result = correct(v1, data)
    batch = AgentTestBatch.find_by(tracking_template: v1)
    expect(batch.day).to eq(AgentTester::AutoCase.today(v1))
    expect(result[:saved_in]).to start_with("Pruebas · #{v1.name} · ")
    expect(batch.cases.sole).to have_attributes(messages: ['¿Becas?'], expected: 'Solo la de 20% primero', origin: 'correction')

    correct(v1, data)
    expect(batch.cases.count).to eq(1)
  end

  it 'otro día, otro lote; «correr todas» junta las pruebas de todos sus días' do
    data = { 'causes' => [{ 'kind' => 'prompt', 'where' => '[ROL]', 'text' => 'Una beca a la vez.' }] }
    correct(v1, data)
    travel_to(2.days.from_now) { correct(v1, data) }
    expect(AgentTestBatch.where(tracking_template: v1).count).to eq(2)

    run = nil
    expect { run = AgentTester::AutoCase.run_all(v1, user: user) }.to have_enqueued_job(AgentTester::RunJob)
    expect(run).to have_attributes(total: 2, label: "Todas las pruebas · #{v1.name}")
  end

  it 'si el entrenador solo pregunta, no se guarda prueba' do
    expect(correct(v1, 'causes' => [], 'question' => '¿Seguro?')).not_to have_key(:saved_in)
    expect(AgentTestBatch.count).to eq(0)
  end

  it 'al corregir Kontrolya un error del motor, se vuelve a correr el lote de correcciones del agente' do
    correct(v1, 'causes' => [{ 'kind' => 'engine', 'type' => 'missing_skill', 'what' => 'mandar el PDF' }])
    report = Motor2Report.last
    expect { report.update!(status: 'fixed') }.to have_enqueued_job(AgentTester::RunJob)
    expect(AgentTestRun.last).to have_attributes(tracking_template_id: v1.id, total: 1)
  end

  it 'motor: queda registrado y le llega a Kontrolya' do
    msg = correct(v1, 'causes' => [{ 'kind' => 'engine', 'type' => 'missing_skill', 'what' => 'mandar el PDF del ERP' }])[:messages].first
    expect(msg[:text]).to include('Es del motor', 'ya quedó registrado')
    expect(Motor2Report.find(msg[:report_id])).to have_attributes(kind: 'missing_skill', tracking_template_id: v1.id)
    expect(AgentTestLog.last.motor2_report_id).to eq(msg[:report_id])
  end
end
