import { shallowMount } from '@vue/test-utils';
import CategoryAPI from 'dashboard/api/cannedResponseCategory';
import CannedCategoriesModal from '../CannedCategoriesModal.vue';

vi.mock('dashboard/api/cannedResponseCategory', () => ({
  default: {
    get: vi.fn(),
    suggestions: vi.fn(),
    create: vi.fn(() => Promise.resolve({})),
    update: vi.fn(() => Promise.resolve({})),
    delete: vi.fn(() => Promise.resolve({})),
    createWith: vi.fn(() => Promise.resolve({})),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const abrir = async () => {
  const wrapper = shallowMount(CannedCategoriesModal, {
    propsData: { show: false },
    mocks: { $t: (c, a) => (a ? `${c} ${JSON.stringify(a)}` : c) },
    stubs: {
      'woot-modal': { template: '<div><slot /></div>' },
      'woot-modal-header': true,
      'fluent-icon': true,
      'woot-button': {
        template: '<button @click="$emit(\'click\')"><slot /></button>',
      },
    },
    directives: { tooltip: {} },
  });
  await wrapper.setProps({ show: true });
  await flushPromises();
  return wrapper;
};

describe('CannedCategoriesModal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CategoryAPI.get.mockResolvedValue({
      data: [{ id: 1, name: 'SSUSA', canned_count: 6 }],
    });
    CategoryAPI.suggestions.mockResolvedValue({
      data: [{ name: 'PATITAS', count: 14, agents: 1, canned_ids: [3, 4] }],
    });
  });

  it('muestra las categorías con cuántas tienen y las sugeridas', async () => {
    const texto = (await abrir()).text();

    expect(texto).toContain('SSUSA');
    expect(texto).toContain('CATEGORIES.COUNT {"count":6}');
    expect(texto).toContain('PATITAS');
    expect(texto).toContain('CATEGORIES.SUGGESTED_AGENTS {"count":1}');
  });

  it('aceptar una sugerida la crea con sus respuestas y avisa', async () => {
    const wrapper = await abrir();
    await wrapper.vm.accept(wrapper.vm.suggestions[0]);
    await flushPromises();

    expect(CategoryAPI.createWith).toHaveBeenCalledWith('PATITAS', [3, 4]);
    expect(wrapper.emitted('changed')).toHaveLength(1);
  });

  it('no deja crear un nombre que rompería la directiva', async () => {
    const wrapper = await abrir();
    await wrapper.setData({ newName: 'VET (2)' });

    expect(wrapper.text()).toContain('CATEGORIES.INVALID_NAME');
    wrapper.vm.create();
    expect(CategoryAPI.create).not.toHaveBeenCalled();

    await wrapper.setData({ newName: 'VET' });
    wrapper.vm.create();
    await flushPromises();
    expect(CategoryAPI.create).toHaveBeenCalledWith({
      canned_response_category: { name: 'VET' },
    });
  });

  it('renombrar y eliminar', async () => {
    const wrapper = await abrir();
    wrapper.vm.startEdit({ id: 1, name: 'SSUSA' });
    await wrapper.setData({ editingName: 'GRUAS' });
    wrapper.vm.saveEdit();
    await flushPromises();
    expect(CategoryAPI.update).toHaveBeenCalledWith(1, {
      canned_response_category: { name: 'GRUAS' },
    });

    wrapper.vm.remove({ id: 1 });
    await flushPromises();
    expect(CategoryAPI.delete).toHaveBeenCalledWith(1);
  });
});
