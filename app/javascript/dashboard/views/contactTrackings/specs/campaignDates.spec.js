import { campaignDateAlerts, hasDateError } from '../campaignDates';

// fix/campanas — avisos de las fechas de una campaña (al guardar y al poner en curso)
describe('campaignDateAlerts', () => {
  const now = new Date('2026-11-19T12:00:00Z');
  const keys = window => campaignDateAlerts(window, now).map(a => a.key);

  it('una ventana normal no avisa nada', () => {
    expect(
      keys({
        scheduledFor: '2026-11-25T12:00:00Z',
        endsAt: '2026-12-10T12:00:00Z',
      })
    ).toEqual([]);
  });

  it('un fin que ya pasó es error e impide ponerla en curso', () => {
    const alerts = campaignDateAlerts(
      { scheduledFor: '2026-11-01T12:00:00Z', endsAt: '2026-11-10T12:00:00Z' },
      now
    );
    expect(alerts.map(a => a.key)).toEqual(['ENDS_PASSED']);
    expect(hasDateError(alerts)).toBe(true);
  });

  it('un fin antes del inicio es error', () => {
    expect(
      keys({
        scheduledFor: '2026-12-10T12:00:00Z',
        endsAt: '2026-12-01T12:00:00Z',
      })
    ).toEqual(['ENDS_BEFORE_START']);
  });

  it('sin inicio, o con inicio pasado, avisa que empieza al ponerla en curso', () => {
    expect(keys({})).toEqual(['NO_START']);
    expect(keys({ scheduledFor: '2026-11-18T12:00:00Z' })).toEqual([
      'START_PASSED',
    ]);
  });

  it('un inicio muy lejano pide revisar la fecha', () => {
    const [alert] = campaignDateAlerts(
      { scheduledFor: '2027-03-01T12:00:00Z' },
      now
    );
    expect(alert).toMatchObject({ key: 'START_FAR', days: 102 });
  });

  it('una ventana de menos de un día avisa sus horas', () => {
    const [alert] = campaignDateAlerts(
      { scheduledFor: '2026-11-20T08:00:00Z', endsAt: '2026-11-20T14:00:00Z' },
      now
    );
    expect(alert).toMatchObject({ key: 'SHORT_WINDOW', hours: 6 });
  });

  it('la ventana corta se mide desde ahora si el inicio ya pasó', () => {
    expect(
      keys({
        scheduledFor: '2026-11-10T12:00:00Z',
        endsAt: '2026-11-19T20:00:00Z',
      })
    ).toEqual(['START_PASSED', 'SHORT_WINDOW']);
  });

  it('un fin dentro de dos días avisa que termina pronto', () => {
    expect(
      keys({
        scheduledFor: '2026-11-01T12:00:00Z',
        endsAt: '2026-11-21T00:00:00Z',
      })
    ).toEqual(['START_PASSED', 'ENDS_SOON']);
  });
});
