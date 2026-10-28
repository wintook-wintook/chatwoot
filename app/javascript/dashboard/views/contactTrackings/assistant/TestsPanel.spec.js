import { shallowMount } from '@vue/test-utils';
import AssistantAPI from 'dashboard/api/assistant';
import TestsPanel from './TestsPanel.vue';

// proyecto@diagrama_agente_ia F2 — docs/diagrama_agente_ia_plan.md §4.1
vi.mock('dashboard/api/assistant', () => ({
  default: {
    dryRun: vi.fn(),
    startTestBattery: vi.fn(),
    testBattery: vi.fn(),
  },
}));

// @vue/test-utils 1.x no trae flushPromises: basta con dejar correr la cola.
const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const montar = (props = {}) =>
  shallowMount(TestsPanel, {
    propsData: { draft: '@ruta(cotizar #cotizar: precios): -', ...props },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
    },
    stubs: {
      'woot-button': {
        template: '<button @click="$emit(\'click\')"><slot /></button>',
      },
    },
  });

describe('TestsPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.localStorage.clear();
  });

  it('en seco corre contra el borrador y elige la prueba para el diagrama', async () => {
    const informe = { routes: { chosen: 'cotizar' }, source: {} };
    AssistantAPI.dryRun.mockResolvedValue({ data: informe });
    const wrapper = montar({ inboxId: 7 });

    await wrapper.find('textarea').setValue('¿cuánto cuesta?');
    await wrapper.findAll('button').at(0).trigger('click');
    await flushPromises();

    expect(AssistantAPI.dryRun).toHaveBeenCalledWith(
      '@ruta(cotizar #cotizar: precios): -',
      '¿cuánto cuesta?',
      7
    );
    expect(wrapper.emitted('select')).toEqual([
      [{ mode: 'dry', result: informe }],
    ]);
    expect(wrapper.text()).toContain('cotizar');
  });

  it('sin agente guardado no deja probar en vivo', () => {
    const wrapper = montar();

    expect(wrapper.text()).toContain('TESTS.SAVE_FIRST');
  });

  it('en vivo manda solo la prueba escrita', async () => {
    AssistantAPI.startTestBattery.mockResolvedValue({ data: { id: 'abc' } });
    AssistantAPI.testBattery.mockResolvedValue({
      data: { status: 'done', results: [] },
    });
    const wrapper = montar({ templateId: 5 });

    await wrapper.find('textarea').setValue('hola');
    await wrapper.findAll('button').at(1).trigger('click');
    await flushPromises();

    expect(AssistantAPI.startTestBattery).toHaveBeenCalledWith(5, {
      briefId: null,
      messages: ['hola'],
    });
    expect(window.localStorage.getItem('assistant/tests/battery/5')).toBe(
      'abc'
    );
  });

  it('lista las pruebas de la pila y al elegir una manda su traza', async () => {
    window.localStorage.setItem('assistant/tests/battery/5', 'abc');
    const traza = { camino: 'kbase', ruta: { nombre: 'cotizar' } };
    AssistantAPI.testBattery.mockResolvedValue({
      data: {
        status: 'done',
        results: [
          {
            message: '¿precio?',
            reply: 'Claro',
            cumple: false,
            motivo: 'inventó',
            traza,
          },
        ],
      },
    });
    const wrapper = montar({ templateId: 5 });
    await flushPromises();

    expect(AssistantAPI.testBattery).toHaveBeenCalledWith('abc');
    const fila = wrapper.findAll('li button').at(0);
    expect(fila.text()).toContain('❌');
    await fila.trigger('click');

    expect(wrapper.emitted('select')).toEqual([
      [{ mode: 'live', traza, reply: 'Claro' }],
    ]);
    expect(wrapper.text()).toContain('inventó');
  });
});
