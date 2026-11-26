import { shallowMount } from '@vue/test-utils';
import WhatsappChannel from 'dashboard/api/channel/whatsappChannel';
import { useAlert } from 'dashboard/composables';
import Reauthorize from '../Reauthorize.vue';

// diag/waba F3 — «Reconectar con Meta».
vi.mock('dashboard/api/channel/whatsappChannel', () => ({
  default: { createEmbeddedSignup: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const mountIt = (props = {}, config = {}) =>
  shallowMount(Reauthorize, {
    propsData: { inbox: { id: 1563 }, ...props },
    mocks: {
      $t: key => key,
      $store: {
        getters: {
          'globalConfig/get': {
            whatsappEmbeddedFacebookAppId: 'app1',
            whatsappEmbeddedFacebookConfigId: 'cfg1',
            ...config,
          },
        },
        dispatch: vi.fn(),
      },
    },
    stubs: {
      'woot-button': {
        props: ['disabled'],
        template:
          '<button :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
      },
      Banner: true,
    },
  });

const metaMessage = data =>
  window.dispatchEvent(
    new MessageEvent('message', {
      origin: 'https://www.facebook.com',
      data: JSON.stringify({ type: 'WA_EMBEDDED_SIGNUP', ...data }),
    })
  );

describe('Reconectar con Meta', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.FB = {
      init: vi.fn(),
      login: vi.fn(cb => cb({ authResponse: { code: 'code1' } })),
    };
  });

  it('abre la ventana de Meta y reconecta la MISMA bandeja con su inbox_id', async () => {
    WhatsappChannel.createEmbeddedSignup.mockResolvedValue({ data: {} });
    const wrapper = mountIt();
    await wrapper.find('[data-test="whatsapp-reconnect"]').trigger('click');
    expect(window.FB.login.mock.calls[0][1]).toMatchObject({
      config_id: 'cfg1',
      response_type: 'code',
    });

    metaMessage({
      event: 'FINISH',
      data: { business_id: 'b1', waba_id: 'w1', phone_number_id: 'p1' },
    });
    await new Promise(resolve => {
      setTimeout(resolve);
    });

    expect(WhatsappChannel.createEmbeddedSignup).toHaveBeenCalledWith({
      code: 'code1',
      business_id: 'b1',
      waba_id: 'w1',
      phone_number_id: 'p1',
      inbox_id: 1563,
    });
    expect(useAlert).toHaveBeenCalledWith('WHATSAPP_HEALTH.RECONNECT.DONE');
    expect(wrapper.emitted('reconnected')).toHaveLength(1);
    wrapper.destroy();
  });

  it('si eligieron otro número, muestra el motivo del servidor', async () => {
    WhatsappChannel.createEmbeddedSignup.mockRejectedValue({
      response: {
        data: { error: 'En la ventana de Meta elegiste otro número' },
      },
    });
    const wrapper = mountIt();
    await wrapper.vm.onSignupComplete({ code: 'c', waba_id: 'w' });
    expect(useAlert).toHaveBeenCalledWith(
      'En la ventana de Meta elegiste otro número'
    );
    expect(wrapper.emitted('reconnected')).toBeUndefined();
    wrapper.destroy();
  });

  it('con la app de Meta mal configurada no abre la ventana y lo dice', async () => {
    const wrapper = mountIt({ appBroken: true });
    expect(
      wrapper.find('[data-test="whatsapp-reconnect"]').attributes('disabled')
    ).toBeDefined();
    wrapper.vm.start();
    expect(window.FB.login).not.toHaveBeenCalled();
    expect(useAlert).toHaveBeenCalledWith(
      'WHATSAPP_HEALTH.RECONNECT.APP_BROKEN'
    );
    wrapper.destroy();
  });

  it('sin App ID o config_id del alta tampoco', () => {
    const wrapper = mountIt({}, { whatsappEmbeddedFacebookConfigId: '' });
    expect(wrapper.vm.disabledReason).toBe(
      'WHATSAPP_HEALTH.RECONNECT.APP_BROKEN'
    );
    wrapper.destroy();
  });

  it('si cancelan en la ventana de Meta, avisa y no guarda nada', async () => {
    window.FB.login = vi.fn();
    const wrapper = mountIt();
    wrapper.vm.start();
    metaMessage({ event: 'CANCEL' });
    expect(useAlert).toHaveBeenCalledWith(
      'WHATSAPP_HEALTH.RECONNECT.CANCELLED'
    );
    expect(WhatsappChannel.createEmbeddedSignup).not.toHaveBeenCalled();
    wrapper.destroy();
  });

  it('con dos en pantalla (aviso rojo y Diagnóstico) solo procesa la que abrió la ventana', async () => {
    WhatsappChannel.createEmbeddedSignup.mockResolvedValue({ data: {} });
    const banner = mountIt({ variant: 'banner' });
    const button = mountIt();
    button.vm.start();
    metaMessage({
      event: 'FINISH',
      data: { business_id: 'b1', waba_id: 'w1', phone_number_id: 'p1' },
    });
    await new Promise(resolve => {
      setTimeout(resolve);
    });
    expect(WhatsappChannel.createEmbeddedSignup).toHaveBeenCalledTimes(1);
    expect(button.emitted('reconnected')).toHaveLength(1);
    expect(banner.emitted('reconnected')).toBeUndefined();
    banner.destroy();
    button.destroy();
  });
});
