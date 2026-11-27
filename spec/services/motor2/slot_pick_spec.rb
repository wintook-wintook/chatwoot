# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — el horario que eligió de los que se le dieron, sin depender del modelo.
RSpec.describe Motor2::SlotPick do
  let(:offered) do
    [{ 'inicio' => '2026-11-27T10:00', 'con' => 'Mariana' }, { 'inicio' => '2026-11-27T10:30', 'con' => 'John' },
     { 'inicio' => '2026-11-27T16:00', 'con' => 'Mariana' }]
  end

  it 'entiende la hora, el orden y la persona' do
    expect(described_class.call('10', offered)['inicio']).to end_with('T10:00')
    expect(described_class.call('a las 10:30', offered)['con']).to eq('John')
    expect(described_class.call('el primero', offered)['inicio']).to end_with('T10:00')
    expect(described_class.call('la última porfa', offered)['inicio']).to end_with('T16:00')
    expect(described_class.call('el de John', offered)['inicio']).to end_with('T10:30')
    expect(described_class.call('4', offered)['inicio']).to end_with('T16:00')
  end

  it 'no adivina: «sí», mensajes largos o con dos posibles' do
    expect(described_class.call('sí', offered)).to be_nil
    expect(described_class.call('con Mariana', offered)).to be_nil
    expect(described_class.call('quiero 2 manicures y también un pedicure para mi esposa por favor', offered)).to be_nil
  end
end
