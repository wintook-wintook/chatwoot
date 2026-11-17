# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — las revisiones del código antes de soltar una respuesta.
RSpec.describe Motor2::Runner do
  let(:account) { create(:account) }
  let(:template) { create(:tracking_template, account: account, engine: '2', motor2: motor2) }
  let(:motor2) { { 'business' => [{ 'label' => 'Inscripción', 'value' => '$1,500' }] } }
  let(:runner) { described_class.new(Motor2::Config.new(template), state: Motor2::State.new, history: [{ role: 'user', content: 'hola' }]) }

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  it 'un monto que salió de la ficha pasa' do
    allow(runner).to receive(:complete).and_return(answer('La inscripción es de $1,500.'))
    expect(runner.call.reply).to eq('La inscripción es de $1,500.')
  end

  it 'los datos del negocio de la empresa también cuentan como vistos' do
    AgentBase::BusinessData.update!(account, 'rows' => [{ 'label' => 'Colegiatura', 'value' => '$4,200 al mes' }])
    allow(runner).to receive(:complete).and_return(answer('La colegiatura es de $4,200.'))
    expect(runner.call.reply).to eq('La colegiatura es de $4,200.')
  end

  it 'un monto que no vio en ningún lado se reescribe' do
    allow(runner).to receive(:complete).and_return(answer('La colegiatura es de $4,200.'), answer('Déjame confirmarlo con el equipo.'))
    result = runner.call
    expect(result.reply).to eq('Déjame confirmarlo con el equipo.')
    expect(result.trace['events']).to include({ 'kind' => 'revision', 'text' => 'unsourced' })
  end

  it 'si insiste en el monto inventado, no se manda' do
    allow(runner).to receive(:complete).and_return(answer('Son $4,200.'), answer('Son $4,200, de verdad.'))
    expect(runner.call.reply).to eq('')
  end

  it 'quita ligas que no vio' do
    allow(runner).to receive(:complete).and_return(answer("Inscríbete aquí: https://inventada.com/x\n¡Te esperamos!"))
    result = runner.call
    expect(result.reply).to eq('¡Te esperamos!')
    expect(result.trace['events'].first['kind']).to eq('ligas_quitadas')
  end

  it 'respuesta vacía de OpenAI: lo intenta otra vez' do
    allow(runner).to receive(:complete).and_return(answer(''), answer('Hola, ¿en qué te ayudo?'))
    expect(runner.call.reply).to eq('Hola, ¿en qué te ayudo?')
  end

  it '[SIN_MENSAJE] no manda nada' do
    allow(runner).to receive(:complete).and_return(answer('[SIN_MENSAJE]'))
    expect(runner.call.reply).to eq('')
  end

  it 'sin OpenAI lo dice' do
    account.hooks.destroy_all
    expect(runner.call.error).to include('OpenAI')
  end
end
