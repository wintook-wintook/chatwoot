import { mount } from '@vue/test-utils';
import PatternMention from './PatternMention.vue';

// proyecto@ai_agent_assistant — la lista que sale al escribir «$» en el chat.
//
// Gemela de DirectiveMention.spec, y por el mismo motivo: los defectos de esta
// familia (evento en kebab-case, componente nunca insertado en la plantilla, slot
// equivocado que antepone «/») no los ve eslint ni una prueba de la lógica en
// aislado. Montar y pulsar es lo único que los caza.

const BLOQUES = [
  {
    key: 'role_identity',
    section: 'rol',
    status: 'ready',
  },
  {
    key: 'sheet_source',
    section: 'fuente',
    status: 'dead_letter',
  },
  {
    key: 'closing_once',
    section: 'cierre',
    status: 'ready',
  },
];

const montar = (props = {}) =>
  mount(PatternMention, {
    propsData: { blocks: BLOQUES, searchKey: '', ...props },
    // Devolver la clave permite comprobar QUÉ se pidió traducir, que es donde
    // estaba el bug del slot: pedía la etiqueta correcta y pintaba otra cosa.
    mocks: { $t: clave => clave },
  });

describe('PatternMention.vue', () => {
  it('lista los bloques con su token «$» listo para insertar', () => {
    const etiquetas = montar()
      .findAll('.mention--box button')
      .wrappers.map(w => w.text())
      .join(' ');

    expect(etiquetas).toContain('$role_identity');
    expect(etiquetas).toContain('$sheet_source');
  });

  // Un bloque que aquí sería letra muerta no se esconde —saber por qué no sirve es
  // la mitad de lo que enseña la biblioteca— pero no encabeza la lista.
  it('pone delante lo que sí se puede usar en este agente', () => {
    const primero = montar().findAll('.mention--box button').at(0);

    expect(primero.text()).toContain('$role_identity');
    expect(primero.text()).not.toContain('$sheet_source');
  });

  it('filtra por la clave del bloque', () => {
    const items = montar({ searchKey: 'sheet' }).findAll(
      '.mention--box button'
    );

    expect(items).toHaveLength(1);
    expect(items.at(0).text()).toContain('$sheet_source');
  });

  // Nadie recuerda 28 claves en inglés: se busca por el nombre que se ve.
  it('filtra también por el nombre traducido del bloque', () => {
    const items = montar({ searchKey: 'closing_once' }).findAll(
      '.mention--box button'
    );

    expect(items).toHaveLength(1);
  });

  it('no se pinta si no hay nada que ofrecer', () => {
    expect(montar({ searchKey: 'zzz' }).isVisible()).toBe(false);
  });

  it('al elegir un patrón emite su token con el «$» delante', async () => {
    const wrapper = montar();
    await wrapper.findAll('.mention--box button').at(0).trigger('click');

    expect(wrapper.emitted('select')).toBeTruthy();
    expect(wrapper.emitted('select')[0]).toEqual(['$role_identity']);
  });
});
