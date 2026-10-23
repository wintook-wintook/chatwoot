import {
  averageTicket,
  compareMoney,
  compareNumbers,
} from '../caseMetricsDelta';

describe('caseMetricsDelta', () => {
  it('compareNumbers: sube es bueno, salvo que menor sea mejor', () => {
    expect(compareNumbers(5, 3)).toEqual({ dir: 'up', diff: 2, good: true });
    expect(compareNumbers(3, 5)).toEqual({ dir: 'down', diff: 2, good: false });
    expect(compareNumbers(10, 14, { lowerIsBetter: true })).toEqual({
      dir: 'down',
      diff: 4,
      good: true,
    });
    expect(compareNumbers(4, 4)).toEqual({ dir: 'same', diff: 0, good: null });
    expect(compareNumbers(4, null)).toBeNull();
  });

  it('compareMoney: solo con una misma moneda', () => {
    expect(
      compareMoney(
        [{ currency: 'MXN', amount: 3000 }],
        [{ currency: 'MXN', amount: 1000 }]
      )
    ).toEqual({ dir: 'up', diff: 2000, good: true, currency: 'MXN' });
    expect(compareMoney([{ currency: 'MXN', amount: 10 }], [])).toEqual({
      dir: 'up',
      diff: 10,
      good: true,
      currency: 'MXN',
    });
    expect(
      compareMoney(
        [{ currency: 'MXN', amount: 1 }],
        [{ currency: 'USD', amount: 1 }]
      )
    ).toBeNull();
  });

  it('averageTicket', () => {
    expect(averageTicket([{ currency: 'MXN', amount: 900, count: 3 }])).toEqual(
      [{ currency: 'MXN', amount: 300 }]
    );
  });
});
