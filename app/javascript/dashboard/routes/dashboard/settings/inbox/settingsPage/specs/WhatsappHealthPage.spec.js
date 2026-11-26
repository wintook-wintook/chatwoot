import { shallowMount } from '@vue/test-utils';
import WhatsappHealthAPI from 'dashboard/api/whatsappHealth';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import WhatsappHealthPage from '../WhatsappHealthPage.vue';

// diag/waba F2 — pestaña «Diagnóstico».
vi.mock('dashboard/api/whatsappHealth', () => ({
  default: { last: vi.fn(), run: vi.fn(), subscribe: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('shared/helpers/clipboard', () => ({ copyTextToClipboard: vi.fn() }));

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const checks = [
  { key: 'app', group: 'system', status: 'fail', title: 'App mal' },
  { key: 'token', group: 'receive', status: 'ok', title: 'Token ok' },
  {
    key: 'webhook',
    group: 'receive',
    status: 'fail',
    title: 'Meta no nos manda',
    action: 'subscribe',
  },
  {
    key: 'display_name',
    group: 'send',
    status: 'warn',
    title: 'Nombre rechazado',
    action: 'open_meta',
  },
  {
    key: 'failed',
    group: 'send',
    status: 'warn',
    title: '2 fallidos',
    lines: ['2 · usa una plantilla'],
  },
];

const reconnectStart = vi.fn();

const mountPage = () =>
  shallowMount(WhatsappHealthPage, {
    propsData: { inbox: { id: 1563, name: 'Ventas', phone_number: '+52' } },
    mocks: {
      $t: (key, vars) =>
        vars ? `${key}:${Object.values(vars).join('|')}` : key,
    },
    stubs: {
      SettingsSection: { template: '<div><slot /></div>' },
      'woot-button': {
        template: '<button @click="$emit(\'click\')"><slot /></button>',
      },
      'fluent-icon': true,
      WhatsappReauthorize: {
        template: '<span />',
        methods: { start: reconnectStart },
      },
    },
  });

describe('WhatsappHealthPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    WhatsappHealthAPI.last.mockResolvedValue({
      data: { checked_at: null, checks: [] },
    });
  });

  it('sin diagnóstico previo lo dice', async () => {
    const wrapper = mountPage();
    await flushPromises();
    expect(WhatsappHealthAPI.last).toHaveBeenCalledWith(1563);
    expect(wrapper.text()).toContain('WHATSAPP_HEALTH.NEVER');
  });

  it('al correrlo agrupa Recibir / Enviar / Sistema y resume', async () => {
    WhatsappHealthAPI.run.mockResolvedValue({
      data: { checked_at: '2026-11-26T22:00:00Z', checks },
    });
    const wrapper = mountPage();
    await flushPromises();
    await wrapper.find('[data-test="health-run"]').trigger('click');
    await flushPromises();

    expect(wrapper.vm.groups.map(g => g.key)).toEqual([
      'receive',
      'send',
      'system',
    ]);
    expect(wrapper.find('[data-test="health-summary"]').text()).toBe(
      'WHATSAPP_HEALTH.SUMMARY_ISSUES:2|2'
    );
    expect(wrapper.find('[data-test="health-check-failed"]').text()).toContain(
      '2 · usa una plantilla'
    );
    expect(wrapper.find('[data-test="health-open-meta"]').exists()).toBe(true);
  });

  it('«Suscribir ahora» pide confirmación y luego suscribe', async () => {
    WhatsappHealthAPI.last.mockResolvedValue({
      data: { checked_at: '2026-11-26T22:00:00Z', checks },
    });
    WhatsappHealthAPI.subscribe.mockResolvedValue({
      data: { checked_at: '2026-11-26T22:05:00Z', checks: [] },
    });
    const wrapper = mountPage();
    await flushPromises();

    await wrapper.find('[data-test="health-subscribe"]').trigger('click');
    expect(WhatsappHealthAPI.subscribe).not.toHaveBeenCalled();
    await wrapper.find('[data-test="health-subscribe-yes"]').trigger('click');
    await flushPromises();

    expect(WhatsappHealthAPI.subscribe).toHaveBeenCalledWith(1563);
    expect(useAlert).toHaveBeenCalledWith(
      'WHATSAPP_HEALTH.ACTIONS.SUBSCRIBE_DONE'
    );
  });

  it('si Meta rechaza la suscripción muestra su motivo', async () => {
    WhatsappHealthAPI.last.mockResolvedValue({
      data: { checked_at: '2026-11-26T22:00:00Z', checks },
    });
    WhatsappHealthAPI.subscribe.mockRejectedValue({
      response: { data: { error: 'El permiso de Meta venció' } },
    });
    const wrapper = mountPage();
    await flushPromises();
    wrapper.vm.subscribeAsk = true;
    await wrapper.vm.subscribe();
    expect(useAlert).toHaveBeenCalledWith('El permiso de Meta venció');
  });

  it('«Cambiar token» lleva a la pestaña Configuración', async () => {
    WhatsappHealthAPI.last.mockResolvedValue({
      data: {
        checked_at: '2026-11-26T22:00:00Z',
        checks: [
          {
            key: 'token',
            group: 'receive',
            status: 'fail',
            title: 'Venció',
            action: 'reconnect',
          },
        ],
      },
    });
    const wrapper = mountPage();
    await flushPromises();
    await wrapper.find('[data-test="health-update-token"]').trigger('click');
    expect(wrapper.emitted('goToTab')[0]).toEqual(['configuration']);
  });

  it('reconectar siempre se puede: dice si no hace falta, si hace falta o si no se sabe', async () => {
    const wrapper = mountPage();
    await flushPromises();
    expect(wrapper.vm.reconnectState).toBe('UNKNOWN');

    wrapper.vm.result = {
      checked_at: 'x',
      checks: [{ key: 'token', status: 'ok' }],
    };
    expect(wrapper.vm.reconnectState).toBe('NOT_NEEDED');

    wrapper.vm.result = {
      checked_at: 'x',
      checks: [{ key: 'reauthorization', status: 'fail' }],
    };
    expect(wrapper.vm.reconnectState).toBe('NEEDED');
  });

  it('el «Reconectar» de una revisión abre la reconexión de la sección', async () => {
    WhatsappHealthAPI.last.mockResolvedValue({
      data: {
        checked_at: '2026-11-26T22:00:00Z',
        checks: [
          {
            key: 'token',
            group: 'receive',
            status: 'fail',
            title: 'Venció',
            action: 'reconnect',
          },
        ],
      },
    });
    const wrapper = mountPage();
    await flushPromises();
    await wrapper.find('[data-test="health-reconnect"]').trigger('click');
    expect(reconnectStart).toHaveBeenCalled();
  });

  it('D8: copia el diagnóstico para soporte', async () => {
    WhatsappHealthAPI.last.mockResolvedValue({
      data: { checked_at: '2026-11-26T22:00:00Z', checks },
    });
    const wrapper = mountPage();
    await flushPromises();
    await wrapper.find('[data-test="health-copy"]').trigger('click');
    const text = copyTextToClipboard.mock.calls[0][0];
    expect(text).toContain('WHATSAPP_HEALTH.REPORT.HEADER:Ventas|+52|1563');
    expect(text).toContain('✗ Meta no nos manda');
    expect(text).toContain('   · 2 · usa una plantilla');
    expect(useAlert).toHaveBeenCalledWith('WHATSAPP_HEALTH.REPORT.COPIED');
  });
});
