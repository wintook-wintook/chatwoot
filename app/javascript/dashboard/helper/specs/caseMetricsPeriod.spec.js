import {
  dayString,
  formatRange,
  parseDay,
  periodRange,
  shiftMonths,
} from '../caseMetricsPeriod';

const now = new Date(2026, 9, 21, 15, 30); // 21 oct 2026, 15:30 local
const day = d => dayString(d);

describe('caseMetricsPeriod', () => {
  it('shiftMonths ajusta el día al largo del mes', () => {
    expect(day(shiftMonths(new Date(2026, 2, 31), -1))).toBe('2026-02-28');
    expect(day(shiftMonths(new Date(2026, 0, 15), -1))).toBe('2025-12-15');
  });

  it('este mes se compara con el mismo tramo del mes anterior', () => {
    const r = periodRange('this_month', { now });
    expect(day(r.from)).toBe('2026-10-01');
    expect(r.to).toBe(now);
    expect(day(r.prevFrom)).toBe('2026-09-01');
    expect(r.prevTo).toEqual(new Date(2026, 8, 21, 15, 30));
  });

  it('mes pasado se compara con el mes completo anterior', () => {
    const r = periodRange('last_month', { now });
    expect([r.from, r.to, r.prevFrom, r.prevTo].map(day)).toEqual([
      '2026-09-01',
      '2026-10-01',
      '2026-08-01',
      '2026-09-01',
    ]);
  });

  it('trimestres y años', () => {
    const q = periodRange('this_quarter', { now });
    expect(day(q.from)).toBe('2026-10-01');
    expect(day(q.prevFrom)).toBe('2026-07-01');
    expect(day(q.prevTo)).toBe('2026-07-21');
    const lq = periodRange('last_quarter', { now });
    expect([lq.from, lq.to, lq.prevFrom].map(day)).toEqual([
      '2026-07-01',
      '2026-10-01',
      '2026-04-01',
    ]);
    const ly = periodRange('last_year', { now });
    expect([ly.from, ly.to, ly.prevFrom, ly.prevTo].map(day)).toEqual([
      '2025-01-01',
      '2026-01-01',
      '2024-01-01',
      '2025-01-01',
    ]);
    expect(day(periodRange('this_year', { now }).prevTo)).toBe('2025-10-21');
  });

  it('personalizado incluye el último día y compara con el mismo largo antes', () => {
    const r = periodRange('custom', { from: '2026-10-05', to: '2026-10-14' });
    expect([r.from, r.to, r.prevFrom, r.prevTo].map(day)).toEqual([
      '2026-10-05',
      '2026-10-15',
      '2026-09-25',
      '2026-10-05',
    ]);
  });

  it('personalizado inválido o clave desconocida → null', () => {
    expect(
      periodRange('custom', { from: '2026-10-10', to: '2026-10-01' })
    ).toBeNull();
    expect(periodRange('custom', {})).toBeNull();
    expect(periodRange('90d', { now })).toBeNull();
  });

  it('parseDay', () => {
    expect(parseDay('2026-02-03')).toEqual(new Date(2026, 1, 3));
    expect(parseDay('')).toBeNull();
  });

  it('formatRange', () => {
    const mon = d => d.toLocaleDateString(undefined, { month: 'short' });
    const sep = new Date(2026, 8, 1);
    const oct = new Date(2026, 9, 1);
    expect(formatRange(sep, new Date(2026, 8, 22), now)).toBe(
      `1–21 ${mon(sep)}`
    );
    expect(formatRange(sep, oct, now)).toBe(`1–30 ${mon(sep)}`);
    expect(formatRange(new Date(2026, 8, 15), new Date(2026, 9, 5), now)).toBe(
      `15 ${mon(sep)} – 4 ${mon(oct)}`
    );
    expect(formatRange(new Date(2025, 0, 1), new Date(2026, 0, 1), now)).toBe(
      `1 ${mon(new Date(2025, 0, 1))} – 31 ${mon(new Date(2025, 11, 1))} 2025`
    );
  });
});
