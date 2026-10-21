import { filtersKey, loadCalc, saveCalc } from '../caseMetricsCalc';
import { moneyList } from '../caseCommercial';

describe('caseMetricsCalc', () => {
  beforeEach(() => window.localStorage.clear());

  it('filtersKey: estable sin importar orden ni vacíos', () => {
    expect(filtersKey({ b: 2, a: 1, c: '' })).toBe(filtersKey({ a: 1, b: 2 }));
    expect(filtersKey({ a: 1 })).not.toBe(filtersKey({ a: 2 }));
  });

  it('guarda y recupera el mismo día', () => {
    saveCalc(1, 'monthly', 'k1', { months: [1] });
    const entry = loadCalc(1, 'monthly');
    expect(entry.key).toBe('k1');
    expect(entry.data).toEqual({ months: [1] });
    expect(loadCalc(1, 'stale')).toBeNull();
  });

  it('de otro día no vale', () => {
    window.localStorage.setItem(
      'case_metrics_calc::1::monthly',
      JSON.stringify({ key: 'k', data: {}, at: 0, day: 'Mon Jan 01 2001' })
    );
    expect(loadCalc(1, 'monthly')).toBeNull();
  });

  it('moneyList: por moneda, nunca sumadas', () => {
    expect(moneyList([])).toBe('—');
    expect(
      moneyList([
        { currency: 'MXN', amount: 10 },
        { currency: 'USD', amount: 5 },
      ])
    ).toMatch(/MXN.*·.*USD/);
  });
});
