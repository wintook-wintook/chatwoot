# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::BriefBudget do
  let(:account) { create(:account) }
  let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, api_key: 'k', last_usage: { 'prompt_tokens' => 10 }) }

  before { allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat) }

  def regla(id, nivel, texto = "Regla larga número #{id} " + ('x' * 120))
    { 'texto' => texto, 'regla_id' => id, 'nivel' => nivel, 'capa' => 'C7 · PROTOCOLO COMERCIAL' }
  end

  it 'un encargo cuyas reglas ya caben no se toca ni llama a la IA' do
    ficha = { 'reglas' => [{ 'texto' => 'Saluda' }], 'prohibiciones' => [{ 'texto' => 'Nunca des precios' }] }

    r = described_class.new(account, ficha: ficha).call

    expect(r[:ficha]).to eq(ficha)
    expect(r[:anexo]).to be_empty
    expect(chat).not_to have_received(:call) if chat.respond_to?(:call)
  end

  it 'junta con la IA, repone la inviolable que soltó y manda las recomendadas al anexo' do
    reglas = Array.new(80) { |i| regla("C7-#{i}", i < 5 ? 'inviolable' : 'obligatoria') } +
             [regla('C7-R1', 'recomendada')]
    allow(chat).to receive(:call).and_return(
      { 'lineas' => [{ 'texto' => 'Una sola pregunta por mensaje', 'ids' => (1..79).map { |i| "C7-#{i}" }, 'tipo' => 'regla' }] }
    )

    r = described_class.new(account, ficha: { 'reglas' => reglas }).call

    textos = r[:ficha]['reglas'].pluck('texto')
    expect(textos).to include('Una sola pregunta por mensaje')
    expect(r[:ficha]['reglas'].find { |l| l['ids'] == ['C7-0'] }['nivel']).to eq('inviolable') # soltada → vuelve
    expect(r[:ficha]['reglas'].first['nivel']).to eq('inviolable') # nivel: el más alto
    expect(r[:anexo].pluck('regla_id')).to eq(['C7-R1'])
    expect(r[:despues]).to be <= described_class::RULES_BUDGET
  end

  it 'elige primero el núcleo del autor y las prohibiciones inviolables; lo que no cabe va al anexo y se cuenta' do
    reglas = Array.new(70) { |i| regla("C3-#{i}", 'inviolable') } +
             [regla('C0-N', 'obligatoria').merge('nucleo' => true)] +
             [regla('C7-P', 'inviolable', "Nunca des precios #{'y' * 130}")]
    allow(chat).to receive(:call).and_return(nil)

    r = described_class.new(account, ficha: { 'reglas' => reglas }).call
    dentro = r[:ficha]['reglas'].pluck('regla_id')

    expect(dentro).to include('C0-N') # núcleo, aunque sea obligatoria
    expect(dentro).to include('C7-P') # prohibición inviolable
    expect(r[:inviolables_fuera]).to be_positive
    expect(r[:despues]).to be <= described_class::RULES_BUDGET
  end

  it 'si todavía no cabe, saca obligatorias al anexo pero nunca una inviolable' do
    reglas = Array.new(80) { |i| regla("C0-#{i}", i.even? ? 'inviolable' : 'obligatoria') }
    allow(chat).to receive(:call).and_return(nil) # la IA no contesta: queda como estaba

    r = described_class.new(account, ficha: { 'reglas' => reglas }).call

    quedan = r[:ficha]['reglas']
    expect(quedan.count { |l| l['nivel'] == 'inviolable' }).to eq(40)
    expect(r[:despues]).to be <= described_class::RULES_BUDGET
    expect(r[:anexo]).not_to be_empty
    expect(r[:anexo].pluck('nivel').uniq).to eq(['obligatoria'])
  end
end
