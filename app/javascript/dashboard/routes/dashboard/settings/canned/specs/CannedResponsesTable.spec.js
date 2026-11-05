import { shallowMount } from '@vue/test-utils';
import CannedResponseAPI from 'dashboard/api/cannedResponse';
import CannedResponsesTable from '../CannedResponsesTable.vue';

vi.mock('dashboard/api/cannedResponse', () => ({
  default: {
    list: vi.fn(),
    vectorize: vi.fn(),
    vectorizeMany: vi.fn(),
    destroyMany: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const fila = (id, extra = {}) => ({
  id,
  short_code: `R${id}`,
  content: `texto ${id}`,
  embedding_state: 'ready',
  created_at: '2026-11-01T10:00:00Z',
  updated_at: '2026-11-04T10:00:00Z',
  ...extra,
});

const respuesta = (records, meta = {}) => ({
  data: {
    payload: records,
    meta: {
      count: records.length,
      page: 1,
      per_page: 25,
      summary: {},
      ...meta,
    },
  },
});

const montar = async () => {
  const wrapper = shallowMount(CannedResponsesTable, {
    mocks: { $t: (c, a) => (a ? `${c} ${JSON.stringify(a)}` : c) },
    stubs: [
      'woot-button',
      'woot-loading-state',
      'woot-delete-modal',
      'fluent-icon',
    ],
    directives: { tooltip: {} },
  });
  await flushPromises();
  return wrapper;
};

describe('CannedResponsesTable', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CannedResponseAPI.list.mockResolvedValue(
      respuesta([fila(1), fila(2, { embedding_state: 'missing' })], {
        count: 30,
        summary: { missing: 1, no_key: 0, failed: 0 },
      })
    );
  });

  it('pide la primera página al servidor y muestra el aviso de toda la cuenta', async () => {
    const wrapper = await montar();

    expect(CannedResponseAPI.list).toHaveBeenCalledWith(
      expect.objectContaining({
        page: 1,
        per_page: 25,
        sort: 'short_code',
        order: 'asc',
      })
    );
    expect(wrapper.findAll('tbody tr')).toHaveLength(2);
    expect(wrapper.text()).toContain('EMBEDDING.BANNER_MISSING {"count":1}');
    expect(
      wrapper.findComponent({ name: 'TableFooter' }).props()
    ).toMatchObject({
      currentPage: 1,
      totalCount: 30,
    });
  });

  it('ordenar y filtrar vuelve a la página 1 con los parámetros', async () => {
    const wrapper = await montar();

    wrapper.vm.sortBy('updated_at');
    expect(CannedResponseAPI.list).toHaveBeenLastCalledWith(
      expect.objectContaining({ sort: 'updated_at', order: 'desc', page: 1 })
    );
    wrapper.vm.sortBy('updated_at');
    expect(CannedResponseAPI.list).toHaveBeenLastCalledWith(
      expect.objectContaining({ order: 'asc' })
    );

    wrapper.vm.goTo(2);
    wrapper.setData({ state: 'not_ready' });
    await flushPromises();
    expect(CannedResponseAPI.list).toHaveBeenLastCalledWith(
      expect.objectContaining({ state: 'not_ready', page: 1 })
    );
  });

  it('vectoriza las seleccionadas (hasta 20) y pone su estado nuevo', async () => {
    CannedResponseAPI.vectorizeMany.mockResolvedValue({
      data: [fila(2, { embedding_state: 'pending' })],
    });
    const wrapper = await montar();

    wrapper.vm.toggle(2);
    await wrapper.vm.vectorizeSelected();

    expect(CannedResponseAPI.vectorizeMany).toHaveBeenCalledWith([2]);
    expect(wrapper.vm.records[1].embedding_state).toBe('pending');
    expect(wrapper.vm.selected).toEqual([]);

    wrapper.setData({ selected: Array.from({ length: 21 }, (_, i) => i) });
    expect(wrapper.vm.tooManyToVectorize).toBe(true);
    await wrapper.vm.vectorizeSelected();
    expect(CannedResponseAPI.vectorizeMany).toHaveBeenCalledTimes(1);
  });

  it('seleccionar todas es solo de la página; eliminar varias recarga', async () => {
    CannedResponseAPI.destroyMany.mockResolvedValue({});
    const wrapper = await montar();

    wrapper.vm.toggleAll();
    expect(wrapper.vm.selected).toEqual([1, 2]);
    await wrapper.vm.deleteSelected();

    expect(CannedResponseAPI.destroyMany).toHaveBeenCalledWith([1, 2]);
    expect(CannedResponseAPI.list).toHaveBeenCalledTimes(2);
  });
});
