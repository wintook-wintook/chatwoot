// diag/llamadas_whatsapp — «Llamar» siempre visible en WhatsApp: activo o desactivado con motivo.
import { shallowMount } from '@vue/test-utils';
import WhatsappCallButton from '../WhatsappCallButton.vue';

const mountButton = (inbox, { active = null } = {}) =>
  shallowMount(WhatsappCallButton, {
    propsData: { conversation: { id: 1, inbox_id: 1 } },
    mocks: {
      $t: (key, params) => (params ? `${key}:${params.inbox}` : key),
      $store: {
        getters: {
          'inboxes/getInbox': () => inbox,
          'whatsappCalls/getActive': active,
          'whatsappCalls/getIncoming': null,
        },
        dispatch: vi.fn(),
      },
    },
    directives: { tooltip: {} },
    stubs: { FluentIcon: true },
  });

const CLOUD = { channel_type: 'Channel::Whatsapp', name: 'Ventas' };

describe('WhatsappCallButton', () => {
  it('con llamadas salientes activas se puede llamar', async () => {
    const wrapper = mountButton({
      ...CLOUD,
      whatsapp_calls: { outbound: true },
    });
    expect(wrapper.find('button').attributes('disabled')).toBeUndefined();
    await wrapper.find('button').trigger('click');
    expect(wrapper.vm.$store.dispatch).toHaveBeenCalledWith(
      'whatsappCalls/call',
      { id: 1, inbox_id: 1 }
    );
  });

  it('API oficial sin llamadas activas: se ve desactivado y dice dónde activarlas', () => {
    const wrapper = mountButton({
      ...CLOUD,
      whatsapp_calls: { outbound: false },
    });
    expect(wrapper.find('button').attributes('disabled')).toBe('disabled');
    expect(wrapper.vm.hint).toBe(
      'WHATSAPP_CALLS.WIDGET.CALL_BUTTON_OFF:Ventas'
    );
  });

  it('UnoAPI o 360dialog: desactivado porque esa conexión no permite llamadas', () => {
    const wrapper = mountButton({ ...CLOUD });
    expect(wrapper.find('button').attributes('disabled')).toBe('disabled');
    expect(wrapper.vm.hint).toBe(
      'WHATSAPP_CALLS.WIDGET.CALL_BUTTON_UNSUPPORTED'
    );
  });

  it('fuera de WhatsApp no aparece', () => {
    const wrapper = mountButton({ channel_type: 'Channel::Email' });
    expect(wrapper.find('button').exists()).toBe(false);
  });
});
