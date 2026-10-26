import { shallowMount } from '@vue/test-utils';
import CampaignEntries from '../CampaignEntries.vue';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';

vi.mock('dashboard/api/trackingCampaigns', () => ({
  default: { getEntries: vi.fn() },
}));

// proyecto@automatizacion_campanas — F5 (docs/automatizacion_campanas_plan.md §7.2)
// @vue/test-utils 1.x no trae flushPromises: basta con dejar correr la cola.
const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });
const t = (key, args) => (args ? `${key} ${JSON.stringify(args)}` : key);

const mountTab = () =>
  shallowMount(CampaignEntries, {
    propsData: { campaignId: 5 },
    mocks: { $t: t },
    stubs: ['TableFooter'],
  });

describe('CampaignEntries', () => {
  beforeEach(() => {
    TrackingCampaignsAPI.getEntries.mockResolvedValue({
      data: {
        summary: { enrolled: 2, batch: 1, automation: 1, skipped: 1 },
        meta: { count: 3, page: 1, per_page: 25 },
        entries: [
          {
            id: 3,
            contact_name: 'Ana',
            source: 'automation',
            automation_rule_name: 'Demo',
            status: 'skipped',
            reason: 'already_enrolled',
            created_at: '2026-10-05T12:00:00Z',
          },
          {
            id: 1,
            contact_name: 'Luis',
            source: 'batch',
            status: 'enrolled',
            reason: null,
            created_at: '2026-10-03T12:00:00Z',
          },
        ],
      },
    });
  });

  it('pide la primera página de la campaña y muestra el resumen', async () => {
    const wrapper = mountTab();
    await flushPromises();

    expect(TrackingCampaignsAPI.getEntries).toHaveBeenCalledWith(5, 1);
    expect(wrapper.text()).toContain(
      'TRACKING_CAMPAIGN_DETAIL.ENTRIES.SUMMARY_AUTOMATION 1'
    );
  });

  it('dice por qué automatización entró y por qué se omitió', async () => {
    const wrapper = mountTab();
    await flushPromises();
    const [skipped, enrolled] = wrapper.vm.entries;

    expect(wrapper.vm.sourceLabel(skipped)).toBe(
      'TRACKING_CAMPAIGN_DETAIL.ENTRIES.SOURCE.automation_named {"name":"Demo"}'
    );
    expect(wrapper.vm.statusLabel(skipped)).toBe(
      'TRACKING_CAMPAIGN_DETAIL.ENTRIES.STATUS.skipped: TRACKING_CAMPAIGN_DETAIL.ENTRIES.REASON.already_enrolled'
    );
    expect(wrapper.vm.sourceLabel(enrolled)).toBe(
      'TRACKING_CAMPAIGN_DETAIL.ENTRIES.SOURCE.batch'
    );
  });

  it('sin inscripciones muestra el texto que explica cómo llegan', async () => {
    TrackingCampaignsAPI.getEntries.mockResolvedValue({
      data: { summary: null, meta: { count: 0 }, entries: [] },
    });
    const wrapper = mountTab();
    await flushPromises();

    expect(wrapper.text()).toContain('TRACKING_CAMPAIGN_DETAIL.ENTRIES.EMPTY');
  });
});
