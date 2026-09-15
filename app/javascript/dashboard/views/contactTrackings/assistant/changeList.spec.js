import { changeRows, hasChanges } from './changeList';

describe('changeList', () => {
  it('ordena lo quitado primero, después lo cambiado, al final lo agregado', () => {
    const rows = changeRows({
      touched: [
        { key: '@ruta(factura)', kind: 'added', declared: true },
        { key: '[ESTILO]', kind: 'changed', declared: true },
        { key: '[NO SIMULAR]', kind: 'removed', declared: false },
      ],
    });

    expect(rows.map(r => r.key)).toEqual([
      '[NO SIMULAR]',
      '[ESTILO]',
      '@ruta(factura)',
    ]);
  });

  // Lo que el modelo tocó sin mencionarlo es lo que hay que mirar.
  it('marca lo que cambió sin declararse', () => {
    const rows = changeRows({
      touched: [
        { key: '[ETIQUETAS]', kind: 'changed', declared: false },
        { key: '@ruta(factura)', kind: 'added', declared: true },
      ],
    });

    expect(rows).toEqual([
      { key: '[ETIQUETAS]', kind: 'changed', undeclared: true },
      { key: '@ruta(factura)', kind: 'added', undeclared: false },
    ]);
  });

  it('descarta filas sin clave o con un tipo desconocido', () => {
    const rows = changeRows({
      touched: [{ kind: 'added' }, { key: 'x', kind: 'renamed' }, null],
    });

    expect(rows).toEqual([]);
  });

  it('dice si hay algo que mostrar', () => {
    expect(hasChanges(null)).toBe(false);
    expect(hasChanges({ summary: [], touched: [] })).toBe(false);
    expect(hasChanges({ summary: ['~ sin emojis'], touched: [] })).toBe(true);
  });
});
