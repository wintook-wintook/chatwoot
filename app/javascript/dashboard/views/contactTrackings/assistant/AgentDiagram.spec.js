import { shallowMount } from '@vue/test-utils';
import AgentDiagram from './AgentDiagram.vue';

// proyecto@diagrama_agente_ia F1 — docs/diagrama_agente_ia_plan.md §4.2
const estructura = () => ({
  blocks: [
    {
      type: 'routes',
      lines: [
        {
          kind: 'route',
          name: 'cotizar',
          tag: 'cotizar',
          source: '{{doc:Lista}}',
        },
        { kind: 'route', name: 'soporte', tag: '', source: '' },
      ],
    },
    { type: 'section', title: 'ROL', body: 'x' },
  ],
});

const montar = (props = {}) =>
  shallowMount(AgentDiagram, {
    propsData: { structure: estructura(), ...props },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
    },
  });

const nodo = (wrapper, texto) =>
  wrapper.findAll('g').wrappers.find(g => g.text().includes(texto));

describe('AgentDiagram', () => {
  it('dibuja un cuadro por nodo y una curva por arista', () => {
    const wrapper = montar();

    // cliente + 2 rutas + 2 fuentes + 2 etiquetas
    expect(wrapper.findAll('g')).toHaveLength(7);
    expect(wrapper.findAll('path')).toHaveLength(6);
  });

  it('dice qué es cada fuente y avisa la etiqueta que falta', () => {
    const texto = montar().text();

    expect(texto).toContain('DIAGRAM.SOURCE_DOC');
    expect(texto).toContain('Lista');
    expect(texto).toContain('DIAGRAM.NODE_NO_TAG');
  });

  it('clic en una ruta pide ir a su línea', async () => {
    const wrapper = montar();
    await nodo(wrapper, 'cotizar').trigger('click');

    expect(wrapper.emitted('goToRoute')).toEqual([['cotizar']]);
  });

  it('clic en una sección pide ir a su línea', async () => {
    const wrapper = montar();
    await wrapper.find('button').trigger('click');

    expect(wrapper.emitted('goToSection')).toEqual([[1]]);
  });

  it('pinta el punto del comprobador en el nodo y lo cuenta', () => {
    const wrapper = montar({
      issues: { 'route:cotizar': { level: 'blocking', messages: ['rota'] } },
    });

    expect(nodo(wrapper, 'cotizar').find('circle').exists()).toBe(true);
    expect(wrapper.findAll('circle')).toHaveLength(1);
    expect(wrapper.text()).toContain('DIAGRAM.ISSUES {"count":1}');
  });

  it('sin bloques muestra el estado vacío', () => {
    const wrapper = montar({ structure: { blocks: [] } });

    expect(wrapper.find('svg').exists()).toBe(false);
    expect(wrapper.findComponent({ name: 'EmptyState' }).exists()).toBe(true);
  });

  // proyecto@diagrama_agente_ia F2
  it('con una prueba elegida enciende su camino y atenúa el resto', () => {
    const wrapper = montar({
      test: {
        mode: 'live',
        traza: { camino: 'conversacional', ruta: { nombre: 'cotizar' } },
        reply: 'hola',
      },
    });

    expect(nodo(wrapper, 'cotizar').attributes('opacity')).toBe('1');
    expect(nodo(wrapper, 'soporte').attributes('opacity')).toBe('0.35');
    // la fuente de cotizar no trajo nada: punto débil
    expect(wrapper.text()).toContain('⚠');
    expect(wrapper.text()).toContain('DIAGRAM.MODE_LIVE');
  });

  it('quitar la prueba avisa a la pantalla', async () => {
    const wrapper = shallowMount(AgentDiagram, {
      propsData: {
        structure: estructura(),
        test: { mode: 'dry', result: { routes: {} } },
      },
      mocks: { $t: clave => clave },
      stubs: {
        'woot-button': {
          template: '<button @click="$emit(\'click\')"><slot /></button>',
        },
      },
    });
    await wrapper.find('button').trigger('click');

    expect(wrapper.emitted('clearHighlight')).toHaveLength(1);
  });
});
