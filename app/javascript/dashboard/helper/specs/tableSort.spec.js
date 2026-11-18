import { sortRows, nextSort, sortArrow } from '../tableSort';

const names = rows => rows.map(r => r.name);

describe('tableSort', () => {
  const rows = [
    { id: 1, name: 'VICTOR MANUEL AGUILAR ' },
    { id: 2, name: '👨🏻‍💻 khriz' },
    { id: 3, name: 'Adulfo López' },
    { id: 4, name: null },
    { id: 5, name: 'adulfo lopez' },
    { id: 6, name: 'Ángel' },
    { id: 7, name: '—' },
  ];

  it('ordena por nombre en español: acentos y mayúsculas iguales, emoji y vacíos al final', () => {
    expect(names(sortRows(rows, r => r.name))).toEqual([
      'Adulfo López',
      'adulfo lopez',
      'Ángel',
      'VICTOR MANUEL AGUILAR ',
      '👨🏻‍💻 khriz',
      null,
      '—',
    ]);
  });

  it('en descendente los vacíos siguen al final', () => {
    const sorted = names(sortRows(rows, r => r.name, 'desc'));
    expect(sorted.slice(-2)).toEqual([null, '—']);
    expect(sorted[0]).toBe('👨🏻‍💻 khriz');
  });

  it('compara números como números y desempata por id', () => {
    const scored = [
      { id: 3, score: 10 },
      { id: 1, score: 9 },
      { id: 2, score: 10 },
      { id: 4, score: null },
    ];
    expect(sortRows(scored, r => r.score, 'desc').map(r => r.id)).toEqual([
      2, 3, 1, 4,
    ]);
  });

  it('no muta el arreglo original', () => {
    const copy = [...rows];
    sortRows(rows, r => r.name);
    expect(rows).toEqual(copy);
  });

  it('nextSort alterna en la misma columna y arranca desc en las de «más es mejor»', () => {
    const start = { key: 'contact', direction: 'asc' };
    expect(nextSort(start, 'contact')).toEqual({
      key: 'contact',
      direction: 'desc',
    });
    expect(nextSort(start, 'score', ['score'])).toEqual({
      key: 'score',
      direction: 'desc',
    });
    expect(nextSort(start, 'status', ['score'])).toEqual({
      key: 'status',
      direction: 'asc',
    });
  });

  it('sortArrow marca la columna activa', () => {
    const state = { key: 'contact', direction: 'desc' };
    expect(sortArrow(state, 'contact')).toBe('↓');
    expect(sortArrow(state, 'score')).toBe('↕');
  });
});
