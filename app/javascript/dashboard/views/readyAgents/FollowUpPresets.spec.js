// Catálogo de plantillas de seguimiento (pestaña de «Cómo habla tu empresa»).
import { shallowMount } from '@vue/test-utils';
import FollowUpPresets from './FollowUpPresets.vue';
import AiFollowUpPresetsAPI from 'dashboard/api/aiFollowUpPresets';

vi.mock('dashboard/api/aiFollowUpPresets', () => ({
  default: {
    list: vi.fn(),
    create: vi.fn(() => Promise.resolve({ data: { payload: {} } })),
    update: vi.fn(() => Promise.resolve({ data: { payload: {} } })),
    delete: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const flushPromises = () =>
  new Promise(r => {
    setTimeout(r);
  });

const preset = {
  id: 5,
  name: 'Distribuidora',
  objective: 'Saber si ya le dio seguimiento a su prospecto',
  instructions: '',
  max_attempts: 2,
  interval_value: 1,
  interval_unit: 'days',
  on_finish: 'notify',
  editable: true,
  created_by: 'John',
};

const mount = async (payload = [preset]) => {
  AiFollowUpPresetsAPI.list.mockResolvedValue({ data: { payload } });
  const wrapper = shallowMount(FollowUpPresets, {
    mocks: { $t: x => x },
    stubs: { WootButton: { template: '<button @click="$emit(\'click\')" />' } },
  });
  await flushPromises();
  return wrapper;
};

describe('FollowUpPresets', () => {
  it('lista las de la cuenta y siempre muestra los ejemplos', async () => {
    const wrapper = await mount();
    expect(wrapper.findAll('[data-test="preset-row"]')).toHaveLength(1);
    expect(wrapper.findAll('[data-test="preset-starter"]').length).toBe(4);
  });

  it('«Agregar a mis plantillas» abre el ejemplo para guardarlo como nueva', async () => {
    const wrapper = await mount([]);
    await wrapper.find('[data-test="preset-add-starter"]').trigger('click');
    expect(wrapper.find('[data-test="preset-form"]').exists()).toBe(true);
    await wrapper.find('[data-test="preset-save"]').trigger('click');
    await flushPromises();
    expect(AiFollowUpPresetsAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({
        name: 'ASSISTANT.AI_FOLLOW_UP.STARTERS.COLLECTION.NAME',
        max_attempts: 3,
      })
    );
  });

  it('editar guarda sobre la misma', async () => {
    const wrapper = await mount();
    await wrapper.find('[data-test="preset-edit"]').trigger('click');
    await wrapper.find('[data-test="preset-objective"]').setValue('Otro');
    await wrapper.find('[data-test="preset-save"]').trigger('click');
    await flushPromises();
    expect(AiFollowUpPresetsAPI.update).toHaveBeenCalledWith(
      5,
      expect.objectContaining({ objective: 'Otro', name: 'Distribuidora' })
    );
  });
});
