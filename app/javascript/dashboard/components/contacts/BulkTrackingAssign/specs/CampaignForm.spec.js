import { shallowMount } from '@vue/test-utils';
import CampaignForm from '../CampaignForm.vue';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import contactTrackingBulkAssignsAPI from 'dashboard/api/contactTrackingBulkAssigns';

vi.mock('dashboard/api/trackingCampaigns', () => ({
  default: { create: vi.fn() },
}));
vi.mock('dashboard/api/contactTrackingBulkAssigns', () => ({
  default: { create: vi.fn(), preview: vi.fn() },
}));
vi.mock('dashboard/api/contacts', () => ({
  default: { filter: vi.fn(() => ({ data: { meta: { count: 0 } } })) },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

// proyecto@automatizacion_campanas — F4 (docs/automatizacion_campanas_plan.md §7.1)
const mountForm = (props = {}) =>
  shallowMount(CampaignForm, {
    propsData: props,
    mocks: {
      $t: key => key,
      $store: {
        getters: {
          'trackingTemplates/getTemplates': [{ id: 3, name: 'Vendedor' }],
          'labels/getLabels': [{ id: 1, title: 'demo' }],
          'customViews/getCustomViewsByFilterType': () => [],
        },
        dispatch: vi.fn(),
      },
    },
    computed: {
      templates: () => [{ id: 3, name: 'Vendedor' }],
      labels: () => [{ id: 1, title: 'demo' }],
    },
    stubs: ['woot-button', 'AudiencePreview'],
  });

describe('CampaignForm con ventana', () => {
  beforeEach(() => vi.clearAllMocks());

  it('arranca por lote, con horario respetado y sin espera', () => {
    const wrapper = mountForm();

    expect(wrapper.vm.mode).toBe('batch');
    expect(wrapper.vm.respectWorkingHours).toBe(true);
    expect(wrapper.vm.entryDelayMinutes).toBe(0);
  });

  it('la continua solo pide nombre y Agente IA, y esconde la audiencia', async () => {
    const wrapper = mountForm();
    await wrapper.setData({ mode: 'continuous' });

    expect(wrapper.vm.canConfirm).toBe(false);
    await wrapper.setData({ campaignName: 'Octubre', selectedTemplateId: 3 });
    expect(wrapper.vm.canConfirm).toBe(true);
    expect(wrapper.findComponent({ name: 'AudiencePreview' }).exists()).toBe(
      false
    );
  });

  it('crea la continua por su endpoint, con la ventana y el tope', async () => {
    TrackingCampaignsAPI.create.mockResolvedValue({
      data: { campaign_id: 9, campaign_name: 'Octubre' },
    });
    const wrapper = mountForm();
    await wrapper.setData({
      mode: 'continuous',
      campaignName: ' Octubre ',
      selectedTemplateId: 3,
      endsAt: '2099-10-31T23:59',
      entryDelayMinutes: 60,
      dailyCap: 200,
    });

    await wrapper.vm.onConfirm();

    expect(TrackingCampaignsAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({
        name: 'Octubre',
        tracking_template_id: 3,
        scheduled_for: null,
        daily_cap: 200,
        entry_delay_minutes: 60,
        respect_working_hours: true,
      })
    );
    expect(contactTrackingBulkAssignsAPI.create).not.toHaveBeenCalled();
    expect(wrapper.emitted('created')[0][0]).toEqual({
      campaign_id: 9,
      campaign_name: 'Octubre',
    });
  });

  it('el lote manda la ventana junto con la audiencia', async () => {
    contactTrackingBulkAssignsAPI.create.mockResolvedValue({ data: {} });
    const wrapper = mountForm();
    await wrapper.setData({
      campaignName: 'Lote',
      selectedTemplateId: 3,
      scheduledFor: '2099-10-01T10:00',
      respectWorkingHours: false,
    });

    await wrapper.vm.onConfirm();

    expect(contactTrackingBulkAssignsAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({
        window: expect.objectContaining({
          respect_working_hours: false,
          ends_at: null,
        }),
      })
    );
  });

  it('avisa si el fin no es posterior al inicio y no deja confirmar', async () => {
    const wrapper = mountForm();
    await wrapper.setData({
      mode: 'continuous',
      campaignName: 'X',
      selectedTemplateId: 3,
      scheduledFor: '2099-10-10T10:00',
      endsAt: '2099-10-01T10:00',
    });

    expect(wrapper.vm.windowError).toBe(
      'BULK_TRACKING_ASSIGN.MODAL.ENDS_BEFORE_START'
    );
    expect(wrapper.vm.canConfirm).toBe(false);
  });

  it('desde Contactos (audiencia ya elegida) no ofrece el tipo', () => {
    const wrapper = mountForm({ presetFilterPayload: [] });

    expect(wrapper.text()).not.toContain('BULK_TRACKING_ASSIGN.MODAL.TYPE_LABEL');
  });
});
