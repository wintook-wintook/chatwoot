require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::DateResolver do
  let(:tz) { 'America/Mexico_City' }
  let(:hoy) { Date.new(2026, 11, 26) }

  def resolver(**opciones) = described_class.new(timezone: tz, today: hoy, **opciones)

  describe 'año de una fecha sin año' do
    it 'una fecha de hace unos días se queda en este año (no salta a 2027 en silencio)' do
      expect(resolver.call('7 nov').date).to eq(Date.new(2026, 11, 7))
      expect(resolver.call('07/11').date).to eq(Date.new(2026, 11, 7))
    end

    it 'una fecha de hace más de medio año es la del año siguiente («15 de enero» dicho en noviembre)' do
      expect(resolver.call('15 de enero').date).to eq(Date.new(2027, 1, 15))
    end

    it 'con año escrito, ese año siempre' do
      expect(resolver.call('07/11/2026').date).to eq(Date.new(2026, 11, 7))
    end
  end

  describe 'fecha=mes/dia' do
    it 'sin la opción, día/mes como siempre' do
      expect(resolver.call('12/03/2026').date).to eq(Date.new(2026, 3, 12))
    end

    it 'con la opción, mes/día (Baker y C.H. Robinson)' do
      expect(resolver(month_first: true).call('FECHA 12/03/2026, HORA 09:00 AM', '09:00 AM').date).to eq(Date.new(2026, 12, 3))
    end

    it 'con la opción, las fechas con el mes en letras no cambian' do
      expect(resolver(month_first: true).call('3 de diciembre').date).to eq(Date.new(2026, 12, 3))
    end
  end

  describe 'Result#past?' do
    let(:ahora) { Time.find_zone(tz).local(2026, 11, 26, 17, 30) }

    def resultado(fecha, hora = nil) = described_class::Result.new(date: fecha, time: hora)

    it 'hoy sin hora NO ya pasó (antes se comparaba con las 00:00)' do
      expect(resultado(Date.new(2026, 11, 26)).past?(tz, now: ahora)).to be(false)
    end

    it 'hoy con una hora que ya pasó, sí; con una hora que viene, no' do
      expect(resultado(Date.new(2026, 11, 26), '14:00').past?(tz, now: ahora)).to be(true)
      expect(resultado(Date.new(2026, 11, 26), '21:00').past?(tz, now: ahora)).to be(false)
    end

    it 'ayer, sí; sin fecha, no' do
      expect(resultado(Date.new(2026, 11, 25)).past?(tz, now: ahora)).to be(true)
      expect(resultado(nil).past?(tz, now: ahora)).to be(false)
    end
  end
end
