import { shallowMount } from '@vue/test-utils';
import FichaTest from './FichaTest.vue';
import FichaReadiness from './FichaReadiness.vue';
import FichaAPI from 'dashboard/api/fichaAgente';

vi.mock('dashboard/api/fichaAgente', () => ({
  default: { test: vi.fn(), testExisting: vi.fn(), testResult: vi.fn() },
}));

const mocks = { $t: clave => clave, $route: { params: { accountId: 2 } } };

const RESULT = {
  total: 2,
  passed: 1,
  default_route: 'precios',
  per_route: [
    {
      route: 'agendar',
      key: 'calendar:3',
      label: 'Agendar citas',
      results: [
        { phrase: 'Quiero agendar', got: 'agendar', ok: true },
        {
          phrase: '¿Hay lugar mañana?',
          got: 'precios',
          got_label: 'Precios',
          ok: false,
        },
      ],
    },
  ],
  real: [
    { phrase: '¿a qué hora abren?', got: 'precios', fallback: true },
    { phrase: 'quiero una cita', got: 'agendar', fallback: false },
  ],
};

describe('FichaTest', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    FichaAPI.test.mockResolvedValue({ data: { turn_id: 'x' } });
    FichaAPI.testResult
      .mockResolvedValueOnce({
        data: { done: false, progress: { done: 1, total: 4 } },
      })
      .mockResolvedValueOnce({ data: { done: true, result: RESULT } });
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  const montar = () =>
    shallowMount(FichaTest, {
      propsData: {
        payload: { name: 'Ventas' },
        routes: [
          { name: 'precios', key: 'google_sheet:1', label: 'Precios' },
          { name: 'agendar', key: 'calendar:3', label: 'Agendar citas' },
        ],
      },
      mocks,
    });

  it('corre en segundo plano, muestra el avance y el resultado', async () => {
    const wrapper = montar();
    await wrapper.vm.run();
    expect(FichaAPI.test).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'Ventas', turn_id: expect.any(String) })
    );
    await vi.advanceTimersByTimeAsync(1600);
    expect(wrapper.vm.progress).toEqual({ done: 1, total: 4 });
    await vi.advanceTimersByTimeAsync(1600);
    expect(wrapper.vm.running).toBe(false);
    expect(wrapper.vm.failures.map(f => f.phrase)).toEqual([
      '¿Hay lugar mañana?',
    ]);
    expect(wrapper.vm.fallbacks.map(f => f.phrase)).toEqual([
      '¿a qué hora abren?',
    ]);
    expect(wrapper.emitted('result')[0][0]).toBe(RESULT);
  });

  it('agregar una frase a una ruta avisa a la pantalla; cambiar algo la deja por repetir', async () => {
    const wrapper = montar();
    wrapper.setData({ result: RESULT, testedPayload: '{"name":"Ventas"}' });
    wrapper.vm.add(RESULT.real[0], 'agendar');
    expect(wrapper.emitted('addPhrase')[0][0]).toEqual({
      key: 'calendar:3',
      route: 'agendar',
      phrase: '¿a qué hora abren?',
    });
    expect(wrapper.vm.failures[0].route).toBe('agendar');
    await wrapper.setProps({
      payload: { name: 'Ventas', phrases: { a: ['b'] } },
    });
    expect(wrapper.vm.stale).toBe(true);
  });
});

describe('FichaTest en un agente que ya existe', () => {
  it('prueba su Entrenamiento y toma las rutas del resultado', async () => {
    FichaAPI.testExisting.mockResolvedValue({ data: { turn_id: 'x' } });
    const wrapper = shallowMount(FichaTest, {
      propsData: { templateId: 7 },
      mocks,
    });
    await wrapper.vm.run();
    expect(FichaAPI.testExisting).toHaveBeenCalledWith(7, expect.any(String));
    expect(FichaAPI.test).not.toHaveBeenCalledWith(
      expect.objectContaining({ template_id: 7 })
    );
    wrapper.setData({
      running: false,
      result: {
        ...RESULT,
        routes: [{ name: 'agendar', key: null, label: 'Agendar' }],
      },
    });
    expect(wrapper.vm.routeList.map(r => r.name)).toEqual(['agendar']);
    wrapper.vm.add(RESULT.real[0], 'agendar');
    expect(wrapper.emitted('addPhrase')[0][0]).toMatchObject({
      route: 'agendar',
    });
  });
});

describe('FichaReadiness', () => {
  const ITEMS = [
    { key: 'openai', status: 'ok', label: 'OpenAI activo' },
    { key: 'channel', status: 'warn', label: 'Sin canal', fix: 'channel' },
    { key: 'resource:x', status: 'warn', label: 'PATITAS', fix: 'canned' },
    { key: 'assignment', status: 'warn', label: 'No atiende', fix: 'activate' },
  ];

  it('cuenta lo que está listo y arma los enlaces a Configuración', () => {
    const wrapper = shallowMount(FichaReadiness, {
      propsData: { items: ITEMS },
      mocks,
    });
    expect(wrapper.vm.readyCount).toBe(1);
    expect(wrapper.vm.link(ITEMS[2])).toBe(
      '/app/accounts/2/settings/canned-response/list'
    );
    expect(wrapper.vm.link(ITEMS[1])).toBeNull();
  });

  it('al crear, activar es una casilla; en uno que existe, un botón', async () => {
    const nuevo = shallowMount(FichaReadiness, {
      propsData: { items: ITEMS, isNew: true, canActivate: true },
      mocks,
    });
    const casilla = nuevo.find('[data-key="assignment"] input');
    await casilla.setChecked(true);
    expect(nuevo.emitted('update:activateOnCreate')[0]).toEqual([true]);

    const existe = shallowMount(FichaReadiness, {
      propsData: { items: ITEMS, canActivate: true },
      mocks,
    });
    expect(existe.find('[data-key="assignment"] input').exists()).toBe(false);
  });
});
