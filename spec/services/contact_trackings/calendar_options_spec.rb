require 'rails_helper'

RSpec.describe ContactTrackings::CalendarOptions do
  describe '.parse' do
    it 'lee duración y horario' do
      expect(described_class.parse('- -> @agendar_calendar(duracion=?, horario=24h)').to_h)
        .to eq(duration: nil, ask_duration: true, all_day: true)
      expect(described_class.parse('@agendar_calendar(duracion=2h)').duration).to eq(120)
      expect(described_class.parse('@agendar_calendar(duracion=90)').duration).to eq(90)
    end

    it 'sin opciones es nil: la agenda de siempre' do
      expect(described_class.parse('- -> @agendar_calendar')).to be_nil
    end
  end

  it '.invalid: lo que el motor no entiende' do
    expect(described_class.invalid('@agendar_calendar(duracion=larga, horario=noche, color=rojo)'))
      .to eq([%w[duracion larga], %w[horario noche], %w[color rojo]])
    expect(described_class.invalid('@agendar_calendar(duracion=?, horario=24h)')).to eq([])
  end

  describe '.duration_in (frases del corpus)' do
    {
      'El servicio tendrá una duración aproximada de una hora' => 60,
      'Favor de cotizar por jornada de 16 horas' => 960,
      'HORARIO: 6:00 pm - 12:00 am' => 360,
      'de 18:00 a 00:00' => 360,
      '2 hrs de maniobra' => 120,
      '45 minutos' => 45,
      'hora y media' => 90
    }.each do |texto, minutos|
      it("#{texto} → #{minutos}") { expect(described_class.duration_in(texto)).to eq(minutos) }
    end

    it 'una hora del día o una cantidad no es duración' do
      ['el martes 30 a las 03:00 hrs', 'a las 10:30', 'de 2 a 3 unidades', 'grúa de 80 t'].each do |texto|
        expect(described_class.duration_in(texto)).to be_nil, texto
      end
    end
  end
end
