# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_que_contestan — juntar candidatas con tres redes: exacta (fichas del
# sujeto en curso), palabras y similitud. No decide nada: que la correcta esté.
RSpec.describe KnowledgeBase::Candidates do
  let(:account) { create(:account) }
  let!(:empresarial) { item('Plan Empresarial — Precio y promociones', 'Precio $3,221. Primera promoción: 38%.', kind: 'ficha') }
  let!(:basico) { item('Plan Básico — Precio y promociones', 'Precio $990. Promoción: 10%.', kind: 'ficha') }
  let!(:horario) { item('Horario de atención', 'Lunes a sábado de 9 a 18 h.', embedding: vector(1)) }
  let!(:envios) { item('Envíos', 'Enviamos a todo el país con descuento en pedidos grandes.', embedding: vector(2)) }
  let(:source) { create(:knowledge_source, account: account) }
  let(:scope) { account.knowledge_items.where(source_type: 'canned_response') }

  def vector(*axes)
    Array.new(1536, 0.0).tap { |v| axes.each { |a| v[a] = 1.0 } }
  end

  def item(title, content, kind: 'general', embedding: nil)
    create(:knowledge_item, account: account, knowledge_source: source, title: title, content: "#{title}: #{content}",
                            metadata: { 'kind' => kind }, embedding: embedding)
  end

  it 'las fichas del sujeto en curso entran primero aunque no se parezcan a la pregunta' do
    found = described_class.new(scope, queries: ['¿hay algún otro descuento?'], question: '¿hay algún otro descuento?',
                                       subjects: ['Plan Empresarial']).call
    expect(found.first.item).to eq(empresarial)
    expect(found.first.via).to include('exacta')
    expect(found.map(&:item)).not_to include(basico)
  end

  it 'por palabras, sin acentos y con el nombre valiendo doble' do
    found = described_class.new(scope, queries: [], question: '¿Cuál es el horario de atencion?').call
    expect(found.first.item).to eq(horario)
    expect(found.first.via).to eq(['palabras'])
    expect(found.first.words).to be >= 2
  end

  it 'por similitud encuentra lo que no comparte palabras' do
    found = described_class.new(scope, queries: ['¿abren el domingo?'], question: '¿abren el domingo?',
                                       embed: ->(_texto) { vector(1) }).call
    expect(found.map(&:item)).to include(horario)
    expect(found.find { |c| c.item == horario }.similarity).to be > 0.9
  end

  it 'una candidata que sale en dos redes se junta' do
    found = described_class.new(scope, queries: ['horario'], question: 'horario', embed: ->(_texto) { vector(1) }).call
    expect(found.find { |c| c.item == horario }.via).to contain_exactly('similitud', 'palabras')
  end

  it 'no trae lo que no coincide por ninguna red' do
    found = described_class.new(scope, queries: [], question: '¿Cuál es el horario?').call
    expect(found.map(&:item)).not_to include(envios)
  end

  it 'sin palabras útiles ni vectores no trae nada' do
    expect(described_class.new(scope, queries: [], question: 'hola buenas').call).to eq([])
  end
end
