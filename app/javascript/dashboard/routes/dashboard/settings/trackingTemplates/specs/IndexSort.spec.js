import { shallowMount } from '@vue/test-utils';
import Index from '../Index.vue';
import AssistantAPI from 'dashboard/api/assistant';

vi.mock('dashboard/api/assistant', () => ({
  default: { audit: vi.fn(), getSessions: vi.fn(), getInventory: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const TEMPLATES = [
  { id: 1, name: 'Bravo', updated_at: '2026-10-01T10:00:00Z', inbox_id: null },
  { id: 2, name: 'alfa', updated_at: '2026-10-20T10:00:00Z', inbox_id: null },
  {
    id: 3,
    name: 'Charlie',
    updated_at: '2026-10-10T10:00:00Z',
    inbox_id: null,
  },
];

const esperar = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const montar = () =>
  shallowMount(Index, {
    mocks: {
      $t: clave => clave,
      $route: { query: {} },
      $router: { push: vi.fn() },
      $store: {
        dispatch: vi.fn().mockResolvedValue(),
        getters: {
          'trackingTemplates/getUIFlags': {},
          'trackingTemplates/getTemplates': TEMPLATES,
          'trackingTemplates/getAllInboxIds': [],
          'inboxes/getInboxes': [{ id: 9 }],
          getCurrentUser: {},
          getCurrentRole: 'administrator',
        },
      },
    },
    stubs: ['woot-button', 'woot-tabs', 'woot-tabs-item', 'woot-label'],
  });

describe('Agentes IA — orden de la tabla', () => {
  beforeEach(() => {
    AssistantAPI.audit.mockResolvedValue({
      data: [
        { id: 1, status: 'routed', defects: 0 },
        { id: 2, status: 'broken', defects: 1 },
        { id: 3, status: 'broken', defects: 4 },
      ],
    });
  });

  it('arranca del más actual al menos actual por fecha de actualización', () => {
    const wrapper = montar();
    expect(wrapper.vm.sortedTemplates.map(t => t.id)).toEqual([2, 3, 1]);
  });

  it('al tocar un encabezado ordena por esa columna y alterna', () => {
    const wrapper = montar();
    wrapper.vm.sortAgentsBy('name');
    const primero = wrapper.vm.sortedTemplates.map(t => t.id);
    wrapper.vm.sortAgentsBy('name');
    const segundo = wrapper.vm.sortedTemplates.map(t => t.id);
    expect(primero).toEqual([...segundo].reverse());
    expect(wrapper.vm.currentPage).toBe(1);
  });

  it('por Revisión, desc deja arriba lo que no ejecuta y con más errores', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.vm.agentsSort = { key: 'review_rank', order: 'desc' };
    expect(wrapper.vm.sortedTemplates.map(t => t.id)).toEqual([3, 2, 1]);
  });
});
