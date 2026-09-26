require 'rails_helper'

RSpec.describe ContactTrackings::AmbiguousDate do
  it 'es ambiguo el día de la semana sin número' do
    ['cotización para el día Lunes a las 08:00', 'el martes a las 10', 'para el jueves en la tarde'].each do |texto|
      expect(described_class.ambiguous?(texto)).to be(true), texto
    end
  end

  it 'no es ambiguo con fecha explícita, ni sin día de la semana' do
    ['el lunes 28', 'lunes 01 de junio', 'martes 30 de junio a las 3', 'el 30/06 a las 03:00', '01-JUN-26 10:00',
     'mañana a las 8', 'a las 10'].each do |texto|
      expect(described_class.ambiguous?(texto)).to be(false), texto
    end
  end

  it 'escribe la fecha completa' do
    at = Time.find_zone('America/Mexico_City').local(2026, 9, 28, 8)
    expect(described_class.note(at, 'America/Mexico_City')).to eq('Entiendo que es el lunes 28 de septiembre')
  end
end
