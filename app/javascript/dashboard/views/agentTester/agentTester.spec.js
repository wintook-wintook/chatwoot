// Probador de agentes — la plática con el motor real (API simulada), el 👎 y las plantillas.
import { shallowMount } from '@vue/test-utils';
import AgentTesterAPI from 'dashboard/api/agentTester';
import AgentTestBatchesApi from 'dashboard/api/agentTestBatches';
import TesterChat from './TesterChat.vue';
import TesterBatches from './TesterBatches.vue';

vi.mock('dashboard/api/agentTester', () => ({
  default: {
    start: vi.fn(),
    say: vi.fn(),
    since: vi.fn(),
    feedback: vi.fn(),
    fixKind: vi.fn(),
    fixStart: vi.fn(),
    fixSource: vi.fn(),
  },
}));
vi.mock('dashboard/api/agentTestBatches', () => ({
  default: {
    addCase: vi.fn(),
    run: vi.fn(),
    compare: vi.fn(),
    importRows: vi.fn(),
    importPila: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const mountChat = () =>
  shallowMount(TesterChat, {
    propsData: { agents: [{ id: 3, name: 'Becas', engine: '1' }] },
    mocks: {
      $t: (k, a) => (a ? `${k} ${JSON.stringify(a)}` : k),
      $router: { resolve: () => ({ href: '#' }) },
    },
    stubs: { WootButton: true },
  });

describe('TesterChat', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('empieza la plática, manda el mensaje y espera lo que conteste el motor', async () => {
    AgentTesterAPI.start.mockResolvedValue({
      data: { conversation_id: 9, template_id: 3, engine: '1', name: 'Becas' },
    });
    AgentTesterAPI.say.mockResolvedValue({ data: { message_id: 50 } });
    AgentTesterAPI.since
      .mockResolvedValueOnce({
        data: {
          messages: [
            {
              id: 51,
              content: 'Hola, soy Sofi',
              private: false,
              lines: ['Ruta: saludo'],
            },
          ],
          tracking_status: 'active',
        },
      })
      .mockResolvedValue({ data: { messages: [], tracking_status: 'active' } });
    const wrapper = mountChat();
    wrapper.vm.templateId = '3';
    await wrapper.vm.start();
    wrapper.vm.draft = 'Hola';
    const sending = wrapper.vm.send();
    await vi.advanceTimersByTimeAsync(14000);
    await sending;
    expect(AgentTesterAPI.say).toHaveBeenCalledWith(9, 'Hola');
    expect(wrapper.vm.chat.map(m => m.content)).toEqual([
      'Hola',
      'Hola, soy Sofi',
    ]);
    expect(wrapper.vm.chat[1].lines).toEqual(['Ruta: saludo']);
  });

  it('👎 manda la corrección y pinta lo que dice el entrenador', async () => {
    AgentTesterAPI.feedback.mockResolvedValue({
      data: { messages: [{ kind: 'engine', text: 'Es del motor' }] },
    });
    const wrapper = mountChat();
    wrapper.vm.session = { conversation_id: 9 };
    wrapper.vm.chat = [
      { role: 'user', content: 'Hola' },
      { role: 'assistant', id: 51, content: 'Mal' },
    ];
    wrapper.vm.rate(1, 'down');
    wrapper.vm.feedback = 'Debió saludar';
    await wrapper.vm.sendFeedback();
    expect(AgentTesterAPI.feedback).toHaveBeenCalledWith(
      9,
      51,
      'Debió saludar'
    );
    expect(wrapper.vm.chat[2]).toMatchObject({
      role: 'trainer',
      content: '🔧 Es del motor',
    });
  });
});

// El webpack del proyecto no entiende `??` ni `?.` dentro de las plantillas.
// proyecto@predefinidas_que_contestan
describe('TesterChat con la búsqueda nueva', () => {
  it('empieza la plática con la búsqueda elegida', async () => {
    AgentTesterAPI.start.mockResolvedValue({
      data: { conversation_id: 9, template_id: 3, engine: '1', name: 'Becas' },
    });
    const wrapper = mountChat();
    wrapper.vm.templateId = '3';
    wrapper.vm.seleccion = 'on';
    await wrapper.vm.start();
    expect(AgentTesterAPI.start).toHaveBeenCalledWith(3, 'on');
  });

  it('«Cambiar categoría» y «Agregar al inicio» corrigen con un clic', async () => {
    AgentTesterAPI.fixKind.mockResolvedValue({ data: { ok: true } });
    AgentTesterAPI.fixStart.mockResolvedValue({ data: { ok: true } });
    const wrapper = mountChat();
    const categoria = { info: { canned_id: 7, should_kind: 'ficha' } };
    await wrapper.vm.fixKind(categoria);
    expect(AgentTesterAPI.fixKind).toHaveBeenCalledWith(7, 'ficha');
    expect(categoria.info.fixed).toBe(true);

    const busqueda = { info: { canned_id: 8, add: '¿Hay descuento?' } };
    await wrapper.vm.fixStart(busqueda);
    expect(AgentTesterAPI.fixStart).toHaveBeenCalledWith(8, '¿Hay descuento?');
  });

  it('si no cabe en el tope dice por qué y ofrece partirla', async () => {
    AgentTesterAPI.fixSource.mockRejectedValue({
      response: { data: { error: 'es muy larga', too_long: true } },
    });
    const wrapper = mountChat();
    const contenido = { info: { canned_id: 7, should: 'x' } };
    await wrapper.vm.fixSource(contenido);
    expect(contenido.info.fixed).toBeUndefined();
    expect(contenido.info.fixError).toBe('es muy larga');
    expect(contenido.info.tooLong).toBe(true);
  });
});

describe('TesterBatches con la búsqueda nueva', () => {
  const mountBatches = () =>
    shallowMount(TesterBatches, {
      propsData: {
        agents: [{ id: 3, name: 'Becas', engine: '1' }],
        batches: [{ id: 5, name: 'Lote', template_id: 3, cases: [{ id: 1 }] }],
      },
      mocks: { $t: (k, a) => (a ? `${k} ${JSON.stringify(a)}` : k) },
      stubs: { WootButton: true },
    });

  it('corre con la búsqueda elegida y compara las dos', async () => {
    AgentTestBatchesApi.run.mockResolvedValue({ data: {} });
    AgentTestBatchesApi.compare.mockResolvedValue({ data: [] });
    const wrapper = mountBatches();
    wrapper.vm.runAgent = { 5: 3 };
    wrapper.vm.seleccion = 'off';
    await wrapper.vm.run({ id: 5 });
    expect(AgentTestBatchesApi.run).toHaveBeenCalledWith(5, 3, 'off');
    await wrapper.vm.compare({ id: 5 });
    expect(AgentTestBatchesApi.compare).toHaveBeenCalledWith(5, 3);
  });

  it('importa filas pegadas de una hoja y la pila vieja del agente', async () => {
    AgentTestBatchesApi.importRows.mockResolvedValue({
      data: { created: 2, skipped: [], batch: { name: 'Importadas' } },
    });
    AgentTestBatchesApi.importPila.mockResolvedValue({
      data: { created: 4, skipped: [], batch: { name: 'Pila' } },
    });
    const wrapper = mountBatches();
    wrapper.vm.agentFilter = '3';
    wrapper.vm.importText = 'Hola\tQue salude';
    await wrapper.vm.importRows(false);
    expect(AgentTestBatchesApi.importRows).toHaveBeenCalledWith(
      3,
      'Hola\tQue salude',
      ''
    );
    expect(wrapper.vm.importResult.created).toBe(2);
    await wrapper.vm.importRows(true);
    expect(AgentTestBatchesApi.importPila).toHaveBeenCalledWith(3);
  });
});

describe('plantillas del probador sin operadores que el webpack no lee', () => {
  const files = import.meta.glob('./*.vue', { eager: true, as: 'raw' });
  Object.entries(files).forEach(([path, source]) => {
    it(path, () => {
      expect(source.slice(source.indexOf('<template>'))).not.toMatch(
        /\?\?|\?\./
      );
    });
  });
});
