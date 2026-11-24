import { mount } from '@vue/test-utils';
import CampaignSimulator from './CampaignSimulator.vue';
import CampaignTestRun from './CampaignTestRun.vue';

// @vue/test-utils 1.x no trae flushPromises.
const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const simulation = {
  contact: { id: 5, name: 'Mario', address: 'mario@ejemplo.com' },
  touches: [
    {
      n: 1,
      wait: null,
      channel: 'email',
      source: 'campaign',
      subject: 'Hola Mario',
      text: 'Hola Mario, mira la promo',
    },
    { n: 2, wait: { value: 2, unit: 'days' }, channel: 'email', source: 'ai' },
  ],
  outcomes: [
    { kind: 'relay_person', to: 'Ana' },
    { kind: 'discarded' },
    { kind: 'no_reply', attempts: 2 },
  ],
  warnings: [],
};

const api = vi.hoisted(() => ({
  simulate: vi.fn(),
  testRun: vi.fn(),
  startTestRun: vi.fn(),
  stopTestRun: vi.fn(),
}));
vi.mock('dashboard/api/motor2Campaigns', () => ({ default: api }));
vi.mock('dashboard/api/contacts', () => ({ default: { search: vi.fn() } }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const stubs = {
  'woot-button': {
    template: '<button @click="$emit(\'click\')"><slot /></button>',
  },
  'fluent-icon': true,
  'router-link': true,
};
const mocks = {
  $t: (key, p) => (p ? `${key} ${JSON.stringify(p)}` : key),
  $te: () => false,
  $route: { params: { accountId: 1 } },
};

describe('Probar la campaña', () => {
  it('Simular: guarda, enseña los toques y explica la decisión del chat', async () => {
    api.simulate.mockResolvedValue({ data: simulation });
    const save = vi.fn().mockResolvedValue(true);
    const wrapper = mount(CampaignSimulator, {
      propsData: { campaignId: 9, save, payload: () => ({}) },
      mocks,
      stubs,
    });
    await wrapper.vm.asMe();
    await flushPromises();
    expect(save).toHaveBeenCalled();
    expect(api.simulate).toHaveBeenCalledWith(9, undefined);
    expect(wrapper.text()).toContain('Hola Mario, mira la promo');
    expect(wrapper.text()).toContain('CAMPAIGNS2.SIM.AI_WRITES');
    expect(wrapper.vm.explain('relay')).toContain('relay_person');
    expect(wrapper.vm.explain('discarded')).toContain('discarded');
  });

  it('Prueba real: manda correos de prueba y enseña cómo va', async () => {
    const started = {
      run: {
        id: 3,
        status: 'finished',
        started_at: '2026-11-23T10:00:00Z',
        every_minutes: 2,
      },
      contacts: [
        {
          contact_id: 1,
          name: 'Prueba',
          address: 'yo@ejemplo.com',
          status: 'enrolled',
          tracking: {
            status: 'scheduled',
            attempt: 1,
            attempts: 3,
            next_at: null,
          },
          messages: [
            {
              id: 1,
              kind: 'outgoing',
              content: 'Hola, mira la promo',
              at: '2026-11-23T10:00:00Z',
            },
          ],
        },
      ],
    };
    api.testRun
      .mockResolvedValueOnce({ data: { run: null, contacts: [] } })
      .mockResolvedValue({ data: started });
    api.startTestRun.mockResolvedValue({ data: started });
    const save = vi.fn().mockResolvedValue(true);
    const wrapper = mount(CampaignTestRun, {
      propsData: { campaignId: 9, save },
      mocks,
      stubs,
    });
    await flushPromises();
    wrapper.setData({ recipients: ['yo@ejemplo.com', ' '], everyMinutes: 2 });
    await wrapper.vm.start();
    await flushPromises();
    expect(api.startTestRun).toHaveBeenCalledWith(
      9,
      [{ email: 'yo@ejemplo.com' }],
      2
    );
    expect(wrapper.text()).toContain('Hola, mira la promo');
  });
});
