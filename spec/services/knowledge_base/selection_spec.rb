# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_que_contestan — la marca con que cada escogida le llega al modelo.
RSpec.describe KnowledgeBase::Selection do
  def item(title, kind)
    build(:knowledge_item, title: title, metadata: { 'kind' => kind })
  end

  it 'se prende por cuenta' do
    account = create(:account)
    expect(described_class.enabled?(account)).to be(false)
    account.update!(custom_attributes: { 'kbase_search' => { 'seleccion' => true } })
    expect(described_class.enabled?(account)).to be(true)
  end

  it 'reconoce el sujeto de una ficha por su nombre, sin acentos ni mayúsculas' do
    expect(described_class.same_subject?('Plan Empresarial — Precio y promociones', 'plan empresarial')).to be(true)
    expect(described_class.same_subject?('Licenciatura en Ciencias de la Educación — Costos', 'Ciencias de la Educacion')).to be(true)
    expect(described_class.same_subject?('Plan Básico — Precio', 'Plan Empresarial')).to be(false)
    expect(described_class.same_subject?('Sucursal Centro: horarios', 'Sucursal Norte')).to be(false)
  end

  it 'marca la ficha del sujeto en curso y la de otro sujeto' do
    expect(described_class.label(item('Plan Empresarial — Precio', 'ficha'), ['Plan Empresarial']))
      .to eq('FICHA DE «Plan Empresarial»')
    expect(described_class.label(item('Plan Básico — Precio', 'ficha'), ['Plan Empresarial']))
      .to eq('FICHA DE OTRO SUJETO: «Plan Básico»')
  end

  it 'marca lo general y las objeciones; sin tipo cuenta como general' do
    expect(described_class.label(item('Horario de atención', 'general'), [])).to eq('GENERAL')
    expect(described_class.label(item('Está muy caro', 'objecion'), [])).to eq('OBJECIÓN DEL CLIENTE')
    expect(described_class.label(build(:knowledge_item, title: 'Sin tipo', metadata: {}), [])).to eq('GENERAL')
  end

  it 'sin ninguna escogida dice qué falta y ofrece solo lo cercano' do
    texto = described_class.none_context('el costo de envío a Monterrey', ['Envíos nacionales'])
    expect(texto).to include('falta: el costo de envío a Monterrey')
    expect(texto).to include('Envíos nacionales')
    expect(texto).to include('No inventes')
  end
end
