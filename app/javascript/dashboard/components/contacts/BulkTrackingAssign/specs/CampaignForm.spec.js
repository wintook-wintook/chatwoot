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
vi.mock('dashboard/api/events', () => ({
  default: { list: vi.fn(() => Promise.resolve({ data: { events: [] } })) },
}));

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
        launch: false, // fix/campanas: nace Guardada
      })
    );
    expect(contactTrackingBulkAssignsAPI.create).not.toHaveBeenCalled();
    expect(wrapper.emitted('created')[0][0]).toEqual({
      campaign_id: 9,
      campaign_name: 'Octubre',
      mode: 'continuous',
      launch: false,
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
    expect(wrapper.vm.dateWarnings.map(alert => alert.key)).toContain(
      'START_PASSED'
    );
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

  // fix/campanas: el formulario solo guarda; se pone en curso desde la tabla o el detalle.
  it('solo ofrece Guardar y Guardar no la pone en curso', async () => {
    TrackingCampaignsAPI.update.mockResolvedValue({
      data: { campaign_id: 12 },
    });
    const wrapper = mountForm({
      campaign: { ...savedBatch, mode: 'continuous', audience: {} },
    });

    const buttons = wrapper.findAll('woot-button-stub');
    expect(buttons.length).toBe(1);
    expect(buttons.at(0).text()).toBe('BULK_TRACKING_ASSIGN.MODAL.SAVE');

    await wrapper.vm.onConfirm();

    expect(TrackingCampaignsAPI.update).toHaveBeenCalledWith(
      12,
      expect.objectContaining({ name: 'Lote', tracking_template_id: 3 })
    );
    expect(TrackingCampaignsAPI.launch).not.toHaveBeenCalled();
    expect(wrapper.emitted('updated')[0][0]).toEqual(
      expect.objectContaining({ launch: false })
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

// Plan-Eventos E3 — apartado «Evento»: suma la condición a la audiencia (por lote).
describe('CampaignForm › Evento', () => {
  const segment = {
    id: 7,
    name: 'Monterrey',
    query: {
      payload: [
        {
          attribute_key: 'city',
          filter_operator: 'equal_to',
          values: ['monterrey'],
          query_operator: null,
        },
      ],
    },
  };

  it('con evento, la audiencia es el segmento Y el evento con su estado', async () => {
    const wrapper = mountForm({}, [segment]);
    await wrapper.setData({
      selectedSegmentId: 7,
      eventId: 4,
      eventStatus: 'no_show',
    });
    expect(wrapper.vm.effectiveFilterPayload).toEqual([
      { ...segment.query.payload[0], query_operator: 'and' },
      {
        attribute_key: 'event',
        filter_operator: 'equal_to',
        values: ['4:no_show'],
        query_operator: null,
      },
    ]);
    expect(wrapper.vm.batchBody()).toMatchObject({
      eventId: 4,
      eventStatus: 'no_show',
    });
  });

  it('solo con evento (sin segmento) ya hay audiencia', async () => {
    const wrapper = mountForm();
    await wrapper.setData({ eventId: 4, eventStatus: 'attended' });
    expect(wrapper.vm.hasAudienceSelected).toBe(true);
    expect(wrapper.vm.effectiveFilterPayload).toHaveLength(1);
  });
});

// fix/campanas — Duplicar: el formulario arranca con los datos de otra campaña (de
// cualquier estado) pero crea una nueva, Guardada.
describe('CampaignForm al duplicar una campaña', () => {
  beforeEach(() => vi.clearAllMocks());

  const running = {
    id: 20,
    name: 'Noviembre',
    mode: 'batch',
    status: 'running',
    tracking_template_id: 3,
    scheduled_for: '2099-11-01T16:00:00Z',
    ends_at: '2099-11-30T16:00:00Z',
    entry_delay_minutes: 15,
    respect_working_hours: false,
    daily_cap: 50,
    stop_when_not_interested: false,
    audience: {
      filter_payload: [{ attribute_key: 'labels', values: ['demo'] }],
      excluded_contact_ids: [4],
      skip_active: true,
      source: { type: 'label', label: 'demo' },
    },
  };

  it('copia la configuración con otro nombre y no es modificar', () => {
    const wrapper = mountForm({ copyFrom: running });

    expect(wrapper.vm.isEditing).toBe(false);
    expect(wrapper.vm.isCopy).toBe(true);
    expect(wrapper.vm).toMatchObject({
      campaignName: 'TRACKING_CAMPAIGNS_VIEW.DUPLICATE_NAME',
      selectedTemplateId: 3,
      audienceType: 'label',
      selectedLabel: 'demo',
      excludedContactIds: [4],
      entryDelayMinutes: 15,
      respectWorkingHours: false,
      dailyCap: 50,
      stopWhenNotInterested: false,
    });
    expect(wrapper.text()).toContain('TRACKING_CAMPAIGNS_VIEW.DUPLICATE_HINT');
  });

  it('al guardar crea una campaña nueva, Guardada', async () => {
    contactTrackingBulkAssignsAPI.create.mockResolvedValue({
      data: { saved: true, campaign_id: 21, campaign_name: 'copia' },
    });
    const wrapper = mountForm({ copyFrom: running });

    await wrapper.vm.onConfirm();

    expect(contactTrackingBulkAssignsAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({
        launch: false,
        templateId: 3,
        audienceSource: { type: 'label', label: 'demo' },
      })
    );
    expect(contactTrackingBulkAssignsAPI.update).not.toHaveBeenCalled();
    expect(TrackingCampaignsAPI.update).not.toHaveBeenCalled();
    expect(wrapper.emitted('created')[0][0]).toEqual(
      expect.objectContaining({ campaign_id: 21, launch: false })
    );
  });
});
