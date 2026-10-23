import { lineDiff, diffHunks, diffStats } from './lineDiff';

describe('lineDiff', () => {
  it('no marca nada entre dos textos iguales', () => {
    expect(lineDiff('a\nb', 'a\nb').every(l => l.type === 'same')).toBe(true);
  });

  it('marca la línea agregada y la quitada', () => {
    expect(lineDiff('a\nb\nc', 'a\nX\nc')).toEqual([
      { type: 'same', text: 'a' },
      { type: 'del', text: 'b' },
      { type: 'add', text: 'X' },
      { type: 'same', text: 'c' },
    ]);
  });

  it('funciona con textos vacíos', () => {
    expect(diffStats('', 'a\nb')).toEqual({ added: 2, removed: 1 });
    expect(diffStats(null, null)).toEqual({ added: 0, removed: 0 });
  });

  // Una regla nueva en un Entrenamiento de 198 líneas no puede mostrar las 198.
  it('resume las líneas iguales lejos de un cambio', () => {
    const base = Array.from({ length: 20 }, (_, i) => `l${i}`);
    const cambiado = [...base];
    cambiado.splice(10, 0, 'nueva');

    const hunks = diffHunks(base.join('\n'), cambiado.join('\n'), 1);

    expect(hunks).toEqual([
      { type: 'skip', count: 9 },
      { type: 'same', text: 'l9' },
      { type: 'add', text: 'nueva' },
      { type: 'same', text: 'l10' },
      { type: 'skip', count: 9 },
    ]);
  });
});
