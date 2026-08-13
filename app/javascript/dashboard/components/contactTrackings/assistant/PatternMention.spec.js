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
    body: 'Eres <rol> de <empresa>.',
    source: 'El mejor agente de la instalación cambia de trato seis veces.',
  },
  {
    key: 'sheet_source',
    section: 'fuente',
    status: 'dead_letter',
    body: '{{hoja:<NOMBRE EXACTO>}}',
    source: 'El agente 42 escribe dos nombres distintos de la misma hoja.',
  },
  {
    key: 'closing_once',
    section: 'cierre',
    status: 'ready',
    body: 'Cuando <condición>, despídete UNA vez.',
    source: 'Tres agentes se despiden y vuelven a preguntar.',
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

  // El detalle va DENTRO de la fila marcada, no en un modal: la fila entera ya es el
  // botón que inserta, y un modal encima del chat robaría el foco del composer.
  it('enseña el texto del bloque y su evidencia en la fila marcada', () => {
    const marcada = montar().findAll('.mention--box button').at(0);

    expect(marcada.text()).toContain('Eres <rol> de <empresa>.');
    expect(marcada.text()).toContain('cambia de trato seis veces');
  });

  it('no despliega el detalle de las filas donde no estás', () => {
    const otra = montar().findAll('.mention--box button').at(1);

    expect(otra.text()).not.toContain('Cuando <condición>');
    expect(otra.text()).not.toContain('vuelven a preguntar');
  });

  // Con el detalle desplegado la fila crece; moverse con el ratón tiene que traerlo
  // consigo, o el detalle se queda mostrando el bloque equivocado.
  it('mueve el detalle al pasar el ratón por otra fila', async () => {
    const wrapper = montar();
    // `woot-dropdown-item` no está registrado en el entorno de pruebas, así que
    // queda como elemento desconocido; el listener nativo sigue ahí, que es lo
    // que aquí se ejercita.
    await wrapper.findAll('woot-dropdown-item').at(1).trigger('mouseover');

    const filas = wrapper.findAll('.mention--box button');
    expect(filas.at(1).text()).toContain('Cuando <condición>');
    expect(filas.at(0).text()).not.toContain('Eres <rol>');
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
