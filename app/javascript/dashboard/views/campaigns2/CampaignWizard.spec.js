import { mount } from '@vue/test-utils';
import CampaignWizard from './CampaignWizard.vue';
import CampaignResults from './CampaignResults.vue';
import { toMarkdown } from './EmailEditor.vue';

const options = {
  sellers: [
    {
      id: 7,
      name: 'Vendedor IA',
      relay: 'agent',
    },
  ],
  inboxes: [
    {
      id: 3,
      name: 'WhatsApp Ventas',
      channel_type: 'Channel::Whatsapp',
      templates: [{ name: 'promo', body: 'Hola {{1}}, tenemos una promo' }],
    },
    { id: 4, name: 'Correo', channel_type: 'Channel::Email', templates: [] },
  ],
  events: [],
};

vi.mock('dashboard/api/motor2Campaigns', () => ({
  default: {
    options: () => Promise.resolve({ data: options }),
    results: () =>
      Promise.resolve({
        data: {
          channel: 'whatsapp',
          campaign: {
            id: 9,
            name: 'Promo',
            status: 'running',
            brief: { kind: 'offer' },
          },
          funnel: {
            enrolled: 10,
            sent: 10,
            delivered: 9,
            read: 6,
            replied: 4,
            interested: 2,
          },
          exits: {},
          kind: {},
          money: {},
          reasons: [],
        },
      }),
  },
}));

const mocks = {
  $t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  $route: { params: {} },
  $router: { push: vi.fn() },
  $store: {
    getters: {
      'labels/getLabels': [{ id: 1, title: 'vip' }],
      'customViews/getCustomViewsByFilterType': () => [],
    },
    dispatch: vi.fn(() => Promise.resolve()),
  },
};
const stubs = {
  WootButton: { template: '<button><slot /></button>' },
  WootSidemenuIcon: true,
  FluentIcon: true,
  WootTabs: { template: '<div><slot /></div>' },
  WootTabsItem: true,
  CampaignChat: true,
};
const flush = () =>
  new Promise(r => {
    setTimeout(r);
  });

describe('CampaignWizard', () => {
  it('con un solo vendedor lo elige (la oferta es de la campaña: no se copia del vendedor); arma la audiencia por etiqueta', async () => {
    const w = mount(CampaignWizard, { mocks, stubs });
    await flush();
    expect(w.vm.form.tracking_template_id).toBe(7);
    await w.vm.$nextTick();
    expect(w.vm.form.brief.offer_what).toBe('');
    w.vm.form.audience.source = { type: 'label', label: 'vip' };
    expect(w.vm.body().audience.filter_payload[0]).toMatchObject({
      attribute_key: 'labels',
      values: ['vip'],
    });
  });

  it('WhatsApp: el primer mensaje de «Probar» es la plantilla del primer toque', async () => {
    const w = mount(CampaignWizard, { mocks, stubs });
    await flush();
    w.vm.form.inbox_id = 3;
    w.vm.setTemplate(1, 'promo');
    expect(w.vm.opener).toBe('Hola Mario, tenemos una promo');
  });

  it('más toques agregan su correo; los bloques salen como markdown', async () => {
    const w = mount(CampaignWizard, { mocks, stubs });
    await flush();
    w.vm.form.touches.attempts = 3;
    await w.vm.$nextTick();
    expect(w.vm.form.touches.emails).toHaveLength(3);
    expect(
      toMarkdown([
        { type: 'heading', text: 'Promo' },
        { type: 'text', text: 'Hola {{contacto}}' },
        { type: 'button', text: 'Ver', url: 'https://x.com' },
      ])
    ).toBe('## Promo\n\nHola {{contacto}}\n\n[Ver](https://x.com)');
  });
});

describe('CampaignWizard › Revisar', () => {
  it('«Más tarde» sin fecha futura o fin antes del inicio no deja lanzar; el resumen dice el ritmo y el tope', async () => {
    const w = mount(CampaignWizard, { mocks, stubs });
    await flush();
    w.vm.form.start = 'later';
    expect(w.vm.scheduleProblem).toContain('WHEN.NEEDS_FUTURE');
    w.vm.form.scheduled_for = new Date(Date.now() + 86400000).toISOString();
    w.vm.form.ends_at = new Date(Date.now() + 3600000).toISOString();
    expect(w.vm.scheduleProblem).toContain('WHEN.ENDS_BEFORE');
    w.vm.form.ends_at = '';
    expect(w.vm.scheduleProblem).toBe('');
    w.vm.form.daily_cap = 80;
    expect(w.vm.reviewLines.join(' ')).toContain('REVIEW.CAP');
    expect(w.vm.reviewLines.join(' ')).toContain('REVIEW.ONE_A_DAY');
  });

  it('cambiar a encuesta quita un relevo «al agente» que ya no aplica', async () => {
    const w = mount(CampaignWizard, { mocks, stubs });
    await flush();
    w.vm.form.brief.relay = 'agent';
    w.vm.form.brief.kind = 'survey';
    await w.vm.$nextTick();
    expect(w.vm.form.brief.relay).toBe('');
  });
});

describe('CampaignResults', () => {
  it('el embudo con % sobre lo enviado (WhatsApp: leídos)', async () => {
    const w = mount(CampaignResults, {
      mocks: { ...mocks, $route: { params: { campaignId: '9' } } },
      stubs,
    });
    await flush();
    const read = w.vm.steps.find(s => s.key === 'read');
    expect(read).toMatchObject({ value: 6, pct: 60, group: 'not_read' });
    expect(w.vm.steps.find(s => s.key === 'clicked')).toBeUndefined();
  });
});
