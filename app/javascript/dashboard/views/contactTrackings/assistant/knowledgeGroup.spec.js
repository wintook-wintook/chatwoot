import {
  withCannedGroup,
  creatable,
  itemState,
  hasPending,
} from './knowledgeGroup';

describe('knowledgeGroup', () => {
  it('las rutas que buscan en todas las predefinidas pasan al grupo', () => {
    const draft = [
      '@ruta(precios #cotizar1: cuánto cuesta): @buscar_predefinidas -> @crear_ticket',
      '@ruta(otra #otra: x): @buscar_predefinidas(VENTAS)',
      '[FIDELIDAD]',
      'Usa @buscar_predefinidas para precios.',
    ].join('\n');

    expect(withCannedGroup(draft, 'PATITAS').split('\n')).toEqual([
      '@ruta(precios #cotizar1: cuánto cuesta): @buscar_predefinidas(PATITAS) -> @crear_ticket',
      '@ruta(otra #otra: x): @buscar_predefinidas(VENTAS)',
      '[FIDELIDAD]',
      'Usa @buscar_predefinidas para precios.',
    ]);
  });

  it('una con <PENDIENTE:> no se puede crear hasta llenarla', () => {
    const item = { status: 'missing', content: 'Cuesta <PENDIENTE: precio>.' };

    expect(hasPending(item.content)).toBe(true);
    expect(creatable(item)).toBe(false);
    expect(creatable({ ...item, content: 'Cuesta $350.' })).toBe(true);
    expect(itemState({ ...item, content: 'Cuesta $350.' })).toBe('ready');
  });

  it('la que ya existe no se crea; la que trae números sin confirmar se marca', () => {
    expect(creatable({ status: 'existing', content: 'x' })).toBe(false);
    expect(
      itemState({ status: 'ready', content: 'Ayuno de 8 h', unverified: ['8'] })
    ).toBe('unverified');
  });
});
