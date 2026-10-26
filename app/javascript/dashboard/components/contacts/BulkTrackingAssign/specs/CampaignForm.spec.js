import { shallowMount } from '@vue/test-utils';
import CampaignForm from '../CampaignForm.vue';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import contactTrackingBulkAssignsAPI from 'dashboard/api/contactTrackingBulkAssigns';

vi.mock('dashboard/api/trackingCampaigns', () => ({
  default: { create: vi.fn(), update: vi.fn(), launch: vi.fn() },
}));
vi.mock('dashboard/api/contactTrackingBulkAssigns', () => ({
  default: { create: vi.fn(), update: vi.fn(), preview: vi.fn() },
}));
vi.mock('dashboard/api/contacts', () => ({
  default: { filter: vi.fn(() => ({ data: { meta: { count: 0 } } })) },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

// proyecto@automatizacion_campanas — F4 (docs/automatizacion_campanas_plan.md §7.1)
const mountForm = (props = {}, segments = []) =>
  shallowMount(CampaignForm, {
    propsData: props,
    mocks: {
      $t: key => key,
      $store: {
        getters: {
          'trackingTemplates/getTemplates': [{ id: 3, name: 'Vendedor' }],
          'labels/getLabels': [{ id: 1, title: 'demo' }],
          'customViews/getCustomViewsByFilterType': () => segments,
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

  it('arranca por lote (un segmento), con horario respetado y sin espera', () => {
    const wrapper = mountForm();

    expect(wrapper.vm.mode).toBe('batch');
    expect(wrapper.vm.audienceType).toBe('segment');
    expect(wrapper.vm.respectWorkingHours).toBe(true);
    expect(wrapper.vm.entryDelayMinutes).toBe(0);
  });

  it('"los que agreguen mis automatizaciones" es una continua: solo pide nombre y Agente IA', async () => {
    const wrapper = mountForm();
    await wrapper.setData({ audienceType: 'automation' });

    expect(wrapper.vm.mode).toBe('continuous');
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
      audienceType: 'automation',
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
      mode: 'continuous',
      launch: true,
    });
  });

  it('Guardar (sin poner en curso) manda launch: false y lo avisa al emitir', async () => {
    contactTrackingBulkAssignsAPI.create.mockResolvedValue({
      data: { saved: true, campaign_id: 5, campaign_name: 'Lote' },
    });
    const wrapper = mountForm();
    await wrapper.setData({
      campaignName: 'Lote',
      selectedTemplateId: 3,
      scheduledFor: '2099-10-01T10:00',
    });

    await wrapper.vm.onConfirm(false);

    expect(contactTrackingBulkAssignsAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({ launch: false })
    );
    expect(wrapper.emitted('created')[0][0]).toEqual(
      expect.objectContaining({ campaign_id: 5, mode: 'batch', launch: false })
    );
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
      audienceType: 'automation',
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

  it('desde Contactos (audiencia ya elegida) no ofrece elegir a quién', () => {
    const wrapper = mountForm({ presetFilterPayload: [] });

    expect(wrapper.text()).not.toContain(
      'BULK_TRACKING_ASSIGN.MODAL.WHO_AUTOMATION'
    );
    expect(wrapper.text()).toContain(
      'BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_FROM_CONTACTS'
    );
  });

  it('las opciones de envío arrancan plegadas', async () => {
    const wrapper = mountForm();

    expect(wrapper.text()).not.toContain(
      'BULK_TRACKING_ASSIGN.MODAL.RESPECT_WORKING_HOURS'
    );
    await wrapper.setData({ showSendOptions: true });
    expect(wrapper.text()).toContain(
      'BULK_TRACKING_ASSIGN.MODAL.RESPECT_WORKING_HOURS'
    );
  });

  it('el resumen dice lo que va a pasar', async () => {
    const wrapper = mountForm();
    expect(wrapper.vm.summaryText).toBe(
      'BULK_TRACKING_ASSIGN.MODAL.SUMMARY_BATCH_NO_DATE'
    );

    await wrapper.setData({ audienceType: 'automation' });
    expect(wrapper.vm.summaryText).toBe(
      'BULK_TRACKING_ASSIGN.MODAL.SUMMARY_CONTINUOUS'
    );
  });

  it('los selectores de segmento y etiqueta siempre se ven; solo se habilita el elegido', async () => {
    const wrapper = mountForm();
    const [segment, label] = wrapper.findAll('select').wrappers.slice(1, 3);

    expect(segment.attributes('disabled')).toBeUndefined();
    expect(label.attributes('disabled')).toBe('disabled');

    await wrapper.setData({ audienceType: 'automation' });
    expect(segment.attributes('disabled')).toBe('disabled');
    expect(label.attributes('disabled')).toBe('disabled');
  });
});

describe('CampaignForm · Excluir en la vista previa', () => {
  it('el evento toggleExclude de la tabla excluye y deshace el contacto', async () => {
    const wrapper = mountForm();
    await wrapper.setData({ selectedTemplateId: 3 });
    const preview = wrapper.findComponent({ name: 'AudiencePreview' });

    preview.vm.$emit('toggleExclude', 5);
    expect(wrapper.vm.excludedContactIds).toEqual([5]);
    preview.vm.$emit('toggleExclude', 5);
    expect(wrapper.vm.excludedContactIds).toEqual([]);
  });
});

describe('CampaignForm al modificar una Guardada', () => {
  beforeEach(() => vi.clearAllMocks());

  const savedBatch = {
    id: 12,
    name: 'Lote',
    mode: 'batch',
    status: 'saved',
    tracking_template_id: 3,
    scheduled_for: '2099-10-01T16:00:00Z',
    ends_at: null,
    entry_delay_minutes: 30,
    respect_working_hours: true,
    audience: {
      filter_payload: [{ attribute_key: 'labels', values: ['demo'] }],
      excluded_contact_ids: [8],
      skip_active: false,
      source: { type: 'label', label: 'demo' },
    },
  };

  it('arranca con los datos de la campaña', () => {
    const wrapper = mountForm({ campaign: savedBatch });

    expect(wrapper.vm).toMatchObject({
      campaignName: 'Lote',
      selectedTemplateId: 3,
      audienceType: 'label',
      selectedLabel: 'demo',
      excludedContactIds: [8],
      skipActive: false,
      entryDelayMinutes: 30,
      showSendOptions: true,
    });
    expect(wrapper.vm.scheduledFor).toMatch(/^2099-10-0\dT\d\d:00$/);
  });

  it('un inicio que ya pasó se muestra con aviso; una audiencia sin origen se usa pero se puede cambiar', async () => {
    const wrapper = mountForm({
      campaign: {
        ...savedBatch,
        scheduled_for: '2020-01-01T10:00:00Z',
        audience: { filter_payload: [{ attribute_key: 'name' }] },
      },
    });

    expect(wrapper.vm.scheduledFor).toMatch(/^2020-01-01T\d\d:00$/);
    expect(wrapper.vm.startPassed).toBe(true);
    expect(wrapper.text()).toContain('BULK_TRACKING_ASSIGN.MODAL.START_PASSED');
    expect(wrapper.vm.allowAudienceSelection).toBe(true);
    expect(wrapper.vm.effectiveFilterPayload).toEqual([
      { attribute_key: 'name' },
    ]);
    expect(wrapper.vm.audienceSource).toBeNull();
    expect(wrapper.text()).toContain(
      'BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_SAVED_HINT'
    );

    // Elegir otra audiencia deja de usar la guardada
    await wrapper.setData({ audienceType: 'label', selectedLabel: 'demo' });
    expect(wrapper.vm.savedFilterPayload).toBeNull();
    expect(wrapper.vm.audienceSource).toEqual({ type: 'label', label: 'demo' });
  });

  it('reconoce el segmento de una Guardada sin origen y conserva sus excluidos', async () => {
    const payload = [
      {
        values: ['312'],
        attribute_key: 'phone_number',
        filter_operator: 'contains',
      },
    ];
    const segment = {
      id: 49,
      name: 'C001',
      // mismas claves en otro orden, como las devuelve el JSONB
      query: {
        payload: [
          {
            filter_operator: 'contains',
            attribute_key: 'phone_number',
            values: ['312'],
          },
        ],
      },
    };
    const wrapper = mountForm(
      {
        campaign: {
          ...savedBatch,
          audience: { filter_payload: payload, excluded_contact_ids: [8] },
        },
      },
      [segment]
    );
    await new Promise(resolve => {
      setTimeout(resolve);
    });

    expect(wrapper.vm).toMatchObject({
      audienceType: 'segment',
      selectedSegmentId: 49,
      savedFilterPayload: null,
      excludedContactIds: [8],
    });
    expect(wrapper.vm.audienceSource).toEqual({
      type: 'segment',
      segment_id: 49,
    });
  });

  it('Guardar modifica la Guardada (no crea otra) y no la pone en curso', async () => {
    contactTrackingBulkAssignsAPI.update.mockResolvedValue({
      data: { saved: true, campaign_id: 12 },
    });
    const wrapper = mountForm({ campaign: savedBatch });

    await wrapper.vm.onConfirm(false);

    expect(contactTrackingBulkAssignsAPI.update).toHaveBeenCalledWith(
      12,
      expect.objectContaining({
        campaignName: 'Lote',
        audienceSource: { type: 'label', label: 'demo' },
      })
    );
    expect(contactTrackingBulkAssignsAPI.create).not.toHaveBeenCalled();
    expect(TrackingCampaignsAPI.launch).not.toHaveBeenCalled();
    expect(wrapper.emitted('updated')[0][0]).toEqual(
      expect.objectContaining({ campaign_id: 12, launch: false })
    );
  });

  it('Guardar y poner en curso guarda los cambios y después la lanza', async () => {
    TrackingCampaignsAPI.update.mockResolvedValue({
      data: { campaign_id: 12 },
    });
    TrackingCampaignsAPI.launch.mockResolvedValue({
      data: { campaign_id: 12, status: 'running' },
    });
    const wrapper = mountForm({
      campaign: { ...savedBatch, mode: 'continuous', audience: {} },
    });

    await wrapper.vm.onConfirm(true);

    expect(TrackingCampaignsAPI.update).toHaveBeenCalledWith(
      12,
      expect.objectContaining({ name: 'Lote', tracking_template_id: 3 })
    );
    expect(TrackingCampaignsAPI.launch).toHaveBeenCalledWith(12);
    expect(wrapper.emitted('updated')[0][0]).toEqual(
      expect.objectContaining({ status: 'running', launch: true })
    );
  });

  it('un fin que ya pasó no deja guardar', () => {
    const wrapper = mountForm({
      campaign: { ...savedBatch, ends_at: '2020-02-01T10:00:00Z' },
    });

    expect(wrapper.vm.endsAt).toMatch(/^2020-02-0\dT\d\d:00$/);
    expect(wrapper.vm.windowError).toBe(
      'BULK_TRACKING_ASSIGN.MODAL.ENDS_PASSED'
    );
    expect(wrapper.vm.canConfirm).toBe(false);
  });
});
