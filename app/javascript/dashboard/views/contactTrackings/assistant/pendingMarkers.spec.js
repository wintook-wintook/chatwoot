import { pendingCount, realBlocking } from './pendingMarkers';

describe('pendingMarkers', () => {
  it('cuenta las marcas, en español y en inglés, aunque se repitan', () => {
    const texto =
      '@ruta(a: <PENDIENTE: frases>): <PENDIENTE: fuente>\n@ruta(b: <PENDIENTE: frases>)\n<PENDING: hours>';

    expect(pendingCount(texto)).toBe(4);
    expect(pendingCount('')).toBe(0);
    expect(pendingCount(null)).toBe(0);
  });

  // Tiene que coincidir con la regla del backend: sin ">" no es una marca.
  it('no cuenta lo que no cierra', () => {
    expect(pendingCount('<PENDIENTE: sin cerrar')).toBe(0);
  });

  it('separa las marcas de los problemas de verdad', () => {
    const validation = {
      blocking: [{ code: 'pending_marker' }, { code: 'unknown_source' }],
    };

    expect(realBlocking(validation).map(f => f.code)).toEqual([
      'unknown_source',
    ]);
    expect(realBlocking(null)).toEqual([]);
  });
});
