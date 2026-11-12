import { shallowMount } from '@vue/test-utils';
import AiFollowUpModal from '../AiFollowUpModal.vue';

vi.mock('dashboard/api/aiFollowUps', () => ({
  default: {
    templates: vi.fn().mockResolvedValue({ data: { payload: [] } }),
    context: vi.fn().mockResolvedValue({ data: {} }),
    forConversation: vi.fn().mockResolvedValue({ data: { payload: [] } }),
    forContact: vi.fn().mockResolvedValue({ data: { payload: [] } }),
  },
}));
vi.mock('dashboard/api/aiFollowUpPresets', () => ({
  default: { get: vi.fn().mockResolvedValue({ data: { payload: [] } }) },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

// ¿Quién le da seguimiento?: Seguimiento IA o un agente a medida (otro motor).
const mount = props =>
  shallowMount(AiFollowUpModal, {
    propsData: { show: true, conversationId: 7, ...props },
    mocks: { $t: key => key, $te: () => true },
    stubs: { WootModal: { template: '<div><slot /></div>' } },
  });

describe('AiFollowUpModal — quién da el seguimiento', () => {
  it('sin agentes a medida no pregunta', () => {
    expect(mount().find('[data-test="follow-up-engine"]').exists()).toBe(false);
  });

  it('con agentes a medida pregunta y «Un agente a medida» abre esos', async () => {
    const wrapper = mount({ customAgents: true });
    expect(wrapper.find('[data-test="follow-up-engine"]').exists()).toBe(true);
    await wrapper
      .find('[data-test="follow-up-engine-custom"]')
      .trigger('click');
    expect(wrapper.emitted('legacy')[0]).toEqual([7]);
  });
});
