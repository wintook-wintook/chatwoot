import { shallowMount } from '@vue/test-utils';
import WhatsappCallsPage from '../WhatsappCallsPage.vue';
import WhatsappCallSettingsAPI from 'dashboard/api/whatsappCallSettings';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/api/whatsappCallSettings', () => ({
  default: { show: vi.fn(), update: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const CONFIG = {
  feature_enabled: true,
  enabled: false,
  direction: 'both',
  ring_strategy: 'cascade',
  call_permission_request_body: '',
  default_permission_body: '¿Te llamamos?',
  calls_webhook: null,
  simulator: false,
  meta_status: { status: 'NOT_SET' },
};

const esperar = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const montar = () => {
  const dispatch = vi.fn();
  const wrapper = shallowMount(WhatsappCallsPage, {
    propsData: { inbox: { id: 3 } },
    mocks: {
      $t: (clave, args) => (args ? `${clave}:${JSON.stringify(args)}` : clave),
      $store: { dispatch },
      $route: { params: { accountId: 2 } },
    },
    stubs: [
      'woot-switch',
      'woot-button',
      'woot-loading-state',
      'SettingsSection',
      'router-link',
    ],
  });
  return { wrapper, dispatch };
};

describe('Pestaña Llamadas de la bandeja', () => {
  beforeEach(() => {
    WhatsappCallSettingsAPI.show.mockResolvedValue({ data: CONFIG });
  });

  it('carga lo guardado y el estado en Meta', async () => {
    const { wrapper } = montar();
    await esperar();
    expect(wrapper.vm.form).toMatchObject({
      enabled: false,
      direction: 'both',
      ring_strategy: 'cascade',
    });
    expect(wrapper.vm.metaStatus).toBe('NOT_SET');
  });

  it('guardar actualiza la bandeja (el botón Llamar la lee) y avisa', async () => {
    WhatsappCallSettingsAPI.update.mockResolvedValue({
      data: { ...CONFIG, enabled: true, calls_webhook: 'manual' },
    });
    const { wrapper, dispatch } = montar();
    await esperar();
    wrapper.vm.form.enabled = true;

    await wrapper.vm.save();

    expect(WhatsappCallSettingsAPI.update).toHaveBeenCalledWith(
      3,
      expect.objectContaining({ enabled: true })
    );
    expect(dispatch).toHaveBeenCalledWith('inboxes/get');
    expect(wrapper.vm.needsManualWebhook).toBe(true);
    expect(useAlert).toHaveBeenCalledWith('WHATSAPP_CALLS.SETTINGS.SAVED');
  });

  it('si Meta no deja, muestra su mensaje', async () => {
    WhatsappCallSettingsAPI.update.mockRejectedValue({
      response: { data: { error: 'Límite insuficiente' } },
    });
    const { wrapper } = montar();
    await esperar();

    await wrapper.vm.save();

    expect(useAlert).toHaveBeenCalledWith(
      'WHATSAPP_CALLS.SETTINGS.META_ERROR:{"message":"Límite insuficiente"}'
    );
  });
});
