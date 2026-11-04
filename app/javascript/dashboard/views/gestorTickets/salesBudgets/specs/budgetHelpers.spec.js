import { quickRange, yearMonths, clientKey, monthKey } from '../budgetHelpers';

describe('budgetHelpers', () => {
  it('arma los 12 meses del año', () => {
    expect(yearMonths(2026)).toHaveLength(12);
    expect(yearMonths(2026)[0]).toBe('2026-01');
    expect(yearMonths(2026)[11]).toBe('2026-12');
  });

  it('rangos rápidos: mes, trimestre y año', () => {
    const today = new Date(2026, 10, 4); // 4 de noviembre
    expect(quickRange('month', today)).toEqual({
      from: '2026-11',
      to: '2026-11',
    });
    expect(quickRange('quarter', today)).toEqual({
      from: '2026-10',
      to: '2026-12',
    });
    expect(quickRange('year', today)).toEqual({
      from: '2026-01',
      to: '2026-12',
    });
    expect(monthKey(2026, 3)).toBe('2026-03');
  });

  it('el cliente es la organización o, sin ella, el contacto', () => {
    expect(clientKey({ organization_id: 4, contact_id: null })).toBe('o:4');
    expect(clientKey({ organization_id: null, contact_id: 9 })).toBe('c:9');
  });
});
