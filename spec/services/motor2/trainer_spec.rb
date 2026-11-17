# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — el entrenador: tres salidas claras al dar 👎 (agente / fuente / motor) o una
# pregunta. OpenAI no se llama: se simula el diagnóstico (#chat) y el juez de las pruebas.
RSpec.describe Motor2::Trainer do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:template) do
    create(:tracking_template, account: account, engine: '2', objective: 'Inscribir alumnos',
                               motor2: { 'instructions' => 'Saluda y pregunta la carrera.' })
  end
  let(:messages) { [{ 'role' => 'user', 'content' => '¿Tienen becas?' }, { 'role' => 'assistant', 'content' => 'Sí, 20% y 35%.' }] }
  let(:trainer) { described_class.new(template, user: user) }

  def diagnose(data)
    allow(trainer).to receive(:chat).and_return(data)
  end

  def correct = trainer.call(messages: messages, reply: 'Sí, 20% y 35%.', feedback: 'Primero solo la de 20%', trace: {})

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    Motor2Version.record!(template, user: user, source: 'create')
  end

  it 'agente: corrige las instrucciones solo, deja versión para deshacer y guarda la prueba' do
    diagnose('causes' => [{ 'kind' => 'agent', 'field' => 'instructions', 'find' => '',
                            'replace' => 'Si preguntan por becas, menciona solo la de 20%.', 'summary' => 'Una beca a la vez' }])
    result = correct

    expect(template.reload.motor2['instructions']).to eq("Saluda y pregunta la carrera.\nSi preguntan por becas, menciona solo la de 20%.")
    message = result[:messages].first
    expect(message).to include(kind: 'agent', text: 'Ya lo corregí: Una beca a la vez. Pruébalo de nuevo.')
    expect(message[:undo_version_id]).to eq(Motor2Version.find_by(tracking_template: template, version: 1).id)
    expect(Motor2Version.where(tracking_template: template).ordered.first.source).to eq('trainer')
    expect(Motor2Test.find(result[:test_id])).to have_attributes(origin: 'correction', expected: 'Primero solo la de 20%')
  end

  it 'agente: si el cambio rompe una prueba que pasaba, no lo aplica' do
    Motor2Test.create!(account: account, tracking_template: template, name: 'Saluda', turns: [{ role: 'user', content: 'Hola' }],
                       expected: 'Saluda', last_run: { 'ok' => true })
    allow_any_instance_of(Motor2::TestRunner).to receive(:run).and_return({ ok: false }) # rubocop:disable RSpec/AnyInstance
    diagnose('causes' => [{ 'kind' => 'agent', 'field' => 'instructions', 'find' => 'Saluda y pregunta la carrera.',
                            'replace' => 'No saludes.' }])

    expect(correct[:messages].first).to include(kind: 'agent_blocked')
    expect(template.reload.motor2['instructions']).to eq('Saluda y pregunta la carrera.')
  end

  it 'fuente: enseña lo que dice y, si es una predefinida, ofrece arreglarla' do
    canned = create(:canned_response, account: account, short_code: 'becas', content: 'Becas de 20% y 35%')
    diagnose('causes' => [{ 'kind' => 'source', 'source' => 'Respuestas predefinidas', 'item' => 'becas',
                            'found' => 'Becas de 20% y 35%', 'should' => 'Beca de 20%' }])

    expect(correct[:messages].first).to include(kind: 'source', found: 'Becas de 20% y 35%', can_fix: true, canned_id: canned.id)
  end

  it 'motor: no es del usuario; se reporta a Kontrolya' do
    diagnose('causes' => [{ 'kind' => 'engine', 'type' => 'missing_skill', 'what' => 'mandar el estado de cuenta en PDF' }])
    message = correct[:messages].first

    expect(message[:text]).to include('búscalo con tu Kontrolya', 'Ya les mandé el reporte')
    expect(Motor2Report.find(message[:report_id])).to have_attributes(kind: 'missing_skill', status: 'new', user_id: user.id,
                                                                      expected: 'Primero solo la de 20%')
  end

  it 'si no está seguro, hace una sola pregunta y no cambia nada' do
    diagnose('causes' => [], 'question' => '¿El precio ya no es correcto, o no debía darlo todavía?')
    expect(correct[:messages]).to eq([{ kind: 'question', text: '¿El precio ya no es correcto, o no debía darlo todavía?' }])
    expect(Motor2Version.where(tracking_template: template).count).to eq(1)
  end

  it 'al marcar corregido el reporte, avisa a quien lo reportó y vuelve a correr las pruebas' do
    report = Motor2Report.create!(account: account, tracking_template: template, user: user, kind: 'ignored')
    expect { report.update!(status: 'fixed') }.to have_enqueued_job(Motor2::RunTestsJob).with(template.id)
    expect(report.reload.fixed_at).to be_present
  end
end
