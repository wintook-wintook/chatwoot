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

  it 'modelo sin cita textual del prompt: no se acepta; se trata como falta de indicación' do
    msg = correct(v1, 'causes' => [{ 'kind' => 'model', 'quote' => 'Pregunta siempre el nombre de la empresa', 'why' => 'x' }])[:messages].first
    expect(msg).to include(kind: 'prompt', suggestion: 'Solo la de 20% primero')
  end

  it 'prompt y modelo a la vez sin evidencia: queda solo el de prompt' do
    result = correct(v1, 'causes' => [{ 'kind' => 'prompt', 'where' => '[ROL]', 'text' => 'Una beca a la vez.' },
                                      { 'kind' => 'model', 'quote' => 'algo que no está', 'why' => 'x' }])
    expect(result[:messages].pluck(:kind)).to eq(['prompt'])
  end

  it 'motor: queda registrado y le llega a Kontrolya' do
    msg = correct(v1, 'causes' => [{ 'kind' => 'engine', 'type' => 'missing_skill', 'what' => 'mandar el PDF del ERP' }])[:messages].first
    expect(msg[:text]).to include('Es del motor', 'ya quedó registrado')
    expect(Motor2Report.find(msg[:report_id])).to have_attributes(kind: 'missing_skill', tracking_template_id: v1.id)
    expect(AgentTestLog.last.motor2_report_id).to eq(msg[:report_id])
  end
end
