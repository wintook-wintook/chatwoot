import { shallowMount } from '@vue/test-utils';
import AssistantAPI from 'dashboard/api/assistant';
import TestsPanel from './TestsPanel.vue';

// proyecto@diagrama_agente_ia F2/F3 — docs/diagrama_agente_ia_plan.md §4.1 y §9.1
vi.mock('dashboard/api/assistant', () => ({
  default: {
    dryRun: vi.fn(),
    testBattery: vi.fn(),
    testCases: vi.fn(),
    addTestCase: vi.fn(),
    generateTestCases: vi.fn(),
    pinTestCase: vi.fn(),
    deleteTestCase: vi.fn(),
    runTestCasesDry: vi.fn(),
    runTestCasesLive: vi.fn(),
    suggestedTests: vi.fn(),
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
        props: ['title'],
        template:
          '<button :data-title="title" @click="$emit(\'click\')"><slot /></button>',
      },
    },
  });

const boton = (wrapper, texto) =>
  wrapper.findAll('button').wrappers.find(b => b.text().includes(texto));

const pila = (cambios = {}) => ({
  data: {
    cases: [
      {
        id: 1,
        message: '¿precio?',
        kind: 'ruta',
        pinned: false,
        dry_changed: true,
        last_dry: { at: 'x', informe: { routes: { chosen: 'cotizar' } } },
        last_live: {
          at: 'y',
          cumple: false,
          motivo: 'inventó',
          reply: 'Claro',
          traza: { camino: 'kbase', ruta: { nombre: 'cotizar' } },
        },
      },
    ],
    dry_run: null,
    live_offer: { case_ids: [1], tokens: 1500, max: 10 },
    ...cambios,
  },
});

describe('TestsPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.localStorage.clear();
  });

  describe('sin guardar', () => {
    it('prueba en seco contra el borrador, la elige y avisa a la pantalla', async () => {
      const informe = { routes: { chosen: 'cotizar' }, source: {} };
      AssistantAPI.dryRun.mockResolvedValue({ data: informe });
      const wrapper = montar({ inboxId: 7 });

      await wrapper.find('textarea').setValue('¿cuánto cuesta?');
      await boton(wrapper, 'TESTS.RUN_DRY').trigger('click');
      await flushPromises();

      expect(AssistantAPI.dryRun).toHaveBeenCalledWith(
        '@ruta(cotizar #cotizar: precios): -',
        '¿cuánto cuesta?',
        7
      );
      expect(wrapper.emitted('select')).toEqual([
        [{ mode: 'dry', result: informe }],
      ]);
      expect(wrapper.emitted('dryRun')[0][0].question).toBe('¿cuánto cuesta?');
      expect(AssistantAPI.testCases).not.toHaveBeenCalled();
      expect(wrapper.text()).toContain('TESTS.HINT_UNSAVED');
    });
  });

  describe('con la pila guardada', () => {
    it('carga la pila, la manda al mapa de calor y elige en vivo si corrió en vivo', async () => {
      AssistantAPI.testCases.mockResolvedValue(pila());
      const wrapper = montar({ templateId: 5 });
      await flushPromises();

      expect(AssistantAPI.testCases).toHaveBeenCalledWith(5);
      expect(wrapper.emitted('cases')[0][0]).toHaveLength(1);
      const fila = wrapper.find('li button');
      expect(fila.text()).toContain('❌');
      expect(fila.text()).toContain('TESTS.CHANGED');
      await fila.trigger('click');

      expect(wrapper.emitted('select')[0][0]).toMatchObject({
        mode: 'live',
        reply: 'Claro',
      });
      await boton(wrapper, 'TESTS.VIEW_DRY').trigger('click');
      expect(wrapper.emitted('select')[1][0]).toEqual({
        mode: 'dry',
        result: { routes: { chosen: 'cotizar' } },
      });
    });

    it('agrega, genera y corre toda en seco contra el borrador', async () => {
      AssistantAPI.testCases.mockResolvedValue(pila());
      AssistantAPI.addTestCase.mockResolvedValue({});
      AssistantAPI.generateTestCases.mockResolvedValue({});
      AssistantAPI.runTestCasesDry.mockResolvedValue({});
      const wrapper = montar({ templateId: 5, inboxId: 3, briefId: 9 });
      await flushPromises();

      await wrapper.find('textarea').setValue('hola');
      await boton(wrapper, 'TESTS.ADD').trigger('click');
      await flushPromises();
      await boton(wrapper, 'TESTS.GENERATE').trigger('click');
      await flushPromises();
      await boton(wrapper, 'TESTS.RUN_ALL_DRY').trigger('click');
      await flushPromises();

      expect(AssistantAPI.addTestCase).toHaveBeenCalledWith(5, 'hola');
      expect(AssistantAPI.generateTestCases).toHaveBeenCalledWith(5, {
        briefId: 9,
      });
      expect(AssistantAPI.runTestCasesDry).toHaveBeenCalledWith(
        5,
        '@ruta(cotizar #cotizar: precios): -',
        3
      );
    });

    it('fija y quita pruebas', async () => {
      AssistantAPI.testCases.mockResolvedValue(pila());
      AssistantAPI.pinTestCase.mockResolvedValue({});
      AssistantAPI.deleteTestCase.mockResolvedValue({});
      const wrapper = montar({ templateId: 5 });
      await flushPromises();

      await wrapper.find('[data-title$="TESTS.PIN"]').trigger('click');
      await flushPromises();
      await wrapper.find('[data-title$="TESTS.REMOVE"]').trigger('click');
      await flushPromises();

      expect(AssistantAPI.pinTestCase).toHaveBeenCalledWith(1, true);
      expect(AssistantAPI.deleteTestCase).toHaveBeenCalledWith(1);
    });

    it('después de publicar avisa qué cambió y ofrece en vivo solo esas, con su costo (D5)', async () => {
      AssistantAPI.testCases.mockResolvedValue(
        pila({
          dry_run: {
            status: 'done',
            trigger: 'publish',
            total: 1,
            changed: [1],
            started_at: 't1',
          },
        })
      );
      AssistantAPI.runTestCasesLive.mockResolvedValue({ data: { id: 'abc' } });
      AssistantAPI.testBattery.mockResolvedValue({
        data: { status: 'running', results: [] },
      });
      const wrapper = montar({ templateId: 5 });
      await flushPromises();

      expect(wrapper.text()).toContain('TESTS.PUBLISH_CHANGED {"count":1}');
      await boton(wrapper, 'TESTS.PUBLISH_RUN_LIVE_COST').trigger('click');
      await flushPromises();

      expect(AssistantAPI.runTestCasesLive).toHaveBeenCalledWith(5, [1]);
      expect(AssistantAPI.testBattery).toHaveBeenCalledWith('abc');
      // Ya visto: no vuelve a salir.
      expect(
        window.localStorage.getItem('assistant/tests/publish-seen/5')
      ).toBe('t1');
      expect(wrapper.text()).not.toContain('TESTS.PUBLISH_CHANGED');
      wrapper.destroy();
    });

    it('si la pila sigue igual lo dice', async () => {
      AssistantAPI.testCases.mockResolvedValue(
        pila({
          dry_run: {
            status: 'done',
            trigger: 'publish',
            total: 4,
            changed: [],
            started_at: 't2',
          },
          live_offer: { case_ids: [], tokens: null },
        })
      );
      const wrapper = montar({ templateId: 5 });
      await flushPromises();

      expect(wrapper.text()).toContain('TESTS.PUBLISH_SAME {"total":4}');
    });
  });

  // F4 — la prueba como evidencia
  describe('evidencia, antes / ahora y sugeridas', () => {
    const conHistoria = () =>
      pila({
        cases: [
          {
            id: 1,
            message: '¿precio?',
            kind: 'ruta',
            pinned: false,
            last_dry: {},
            previous_dry: {},
            last_live: {
              at: 'y',
              cumple: false,
              motivo: 'inventó',
              reply: 'Claro',
              traza: { camino: 'conversacional', ruta: { nombre: 'cotizar' } },
            },
            previous_live: {
              at: 'x',
              cumple: true,
              reply: 'Antes',
              traza: { camino: 'kbase', ruta: { nombre: 'cotizar' } },
            },
          },
        ],
      });

    it('lleva la prueba elegida y las rojas al chat', async () => {
      AssistantAPI.testCases.mockResolvedValue(conHistoria());
      const wrapper = montar({ templateId: 5, canSendToChat: true });
      await flushPromises();

      await boton(wrapper, 'TESTS.SEND_FAILING').trigger('click');
      await wrapper.find('li button').trigger('click');
      await boton(wrapper, 'TESTS.SEND_TO_CHAT').trigger('click');

      const enviadas = wrapper.emitted('evidence');
      expect(enviadas).toHaveLength(2);
      enviadas.forEach(([texto]) => expect(texto).toContain('¿precio?'));
    });

    it('sin Entrenamiento en pantalla no ofrece llevar al chat', async () => {
      AssistantAPI.testCases.mockResolvedValue(conHistoria());
      const wrapper = montar({ templateId: 5, canSendToChat: false });
      await flushPromises();

      expect(boton(wrapper, 'TESTS.SEND_FAILING')).toBeUndefined();
    });

    it('avisa lo que se rompió, muestra antes y ahora, y deja ver el antes', async () => {
      AssistantAPI.testCases.mockResolvedValue(conHistoria());
      const wrapper = montar({ templateId: 5 });
      await flushPromises();

      expect(wrapper.text()).toContain(
        'TESTS.COMPARE {"before":1,"after":0,"total":1}'
      );
      expect(wrapper.text()).toContain('TESTS.COMPARE_BROKEN');
      await wrapper.find('li button').trigger('click');
      expect(wrapper.text()).toContain('TESTS.BEFORE');
      await boton(wrapper, 'TESTS.VIEW_BEFORE').trigger('click');

      expect(wrapper.emitted('select').pop()[0]).toEqual({
        mode: 'live',
        traza: { camino: 'kbase', ruta: { nombre: 'cotizar' } },
        reply: 'Antes',
      });
    });

    it('agrega una sugerida a la pila con su ruta esperada', async () => {
      AssistantAPI.testCases.mockResolvedValue(pila({ cases: [] }));
      AssistantAPI.suggestedTests.mockResolvedValue({
        data: {
          cases: [
            {
              message: '¿cuánto sale?',
              expected: 'cotizar',
              chosen: 'cotizar',
              pass: true,
            },
          ],
        },
      });
      AssistantAPI.addTestCase.mockResolvedValue({});
      const wrapper = montar({ templateId: 5, inboxId: 2 });
      await flushPromises();

      await boton(wrapper, 'TESTS.SUGGEST').trigger('click');
      await flushPromises();
      expect(AssistantAPI.suggestedTests).toHaveBeenCalledWith(
        '@ruta(cotizar #cotizar: precios): -',
        null,
        2
      );
      await boton(wrapper, 'TESTS.ADD_SHORT').trigger('click');
      await flushPromises();

      expect(AssistantAPI.addTestCase).toHaveBeenCalledWith(
        5,
        '¿cuánto sale?',
        'cotizar'
      );
    });

    it('sin guardar, la sugerida queda como prueba suelta', async () => {
      AssistantAPI.suggestedTests.mockResolvedValue({
        data: {
          cases: [{ message: 'hola', chosen: 'soporte', tag: '#soporte' }],
        },
      });
      const wrapper = montar();

      await boton(wrapper, 'TESTS.SUGGEST').trigger('click');
      await flushPromises();
      await boton(wrapper, 'TESTS.ADD_SHORT').trigger('click');

      expect(wrapper.find('li').text()).toContain('hola');
      expect(AssistantAPI.addTestCase).not.toHaveBeenCalled();
    });
  });
});
