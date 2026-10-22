import { shallowMount } from '@vue/test-utils';
import WhatsappCallWidget from './WhatsappCallWidget.vue';
import WhatsappCallButton from './WhatsappCallButton.vue';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const store = (getters = {}) => ({
  dispatch: vi.fn(),
  getters: {
    'whatsappCalls/getIncoming': null,
    'whatsappCalls/getActive': null,
    'whatsappCalls/isBusy': false,
    'whatsappCalls/getNotice': null,
    getCurrentAccountId: 2,
    'inboxes/getInbox': () => ({
      name: 'Ventas WA',
      whatsapp_calls: { outbound: true },
    }),
    ...getters,
  },
});

describe('Ventana de llamada', () => {
  const montar = getters =>
    shallowMount(WhatsappCallWidget, {
      mocks: {
        $t: clave => clave,
        $store: store(getters),
        $router: { push: vi.fn() },
      },
      stubs: ['woot-button', 'Draggable', 'Thumbnail'],
    });

  beforeEach(() => {
    window.HTMLMediaElement.prototype.play = vi.fn().mockResolvedValue();
    window.HTMLMediaElement.prototype.pause = vi.fn();
  });

  it('sin llamada no se muestra', () => {
    expect(montar().html()).toBe('');
  });

  it('sonando: quién llama y la bandeja, con Contestar y Rechazar', () => {
    const wrapper = montar({
      'whatsappCalls/getIncoming': {
        id: 5,
        inbox_id: 3,
        caller: { name: 'Juan', phone: '+52' },
      },
    });
    expect(wrapper.vm.isRinging).toBe(true);
    expect(wrapper.vm.callerName).toBe('Juan');
    expect(wrapper.vm.inboxName).toBe('Ventas WA');
    expect(wrapper.vm.statusText).toBe('WHATSAPP_CALLS.WIDGET.INCOMING');
  });

  it('en curso muestra el cronómetro', () => {
    const wrapper = montar({
      'whatsappCalls/getActive': {
        id: 5,
        status: 'in_progress',
        startedAt: Date.now() - 65000,
      },
    });
    wrapper.vm.now = Date.now();
    expect(wrapper.vm.statusText).toBe('01:05');
  });

  // F7 (P1): el guion para avisar en voz, solo con la llamada en curso y grabando
  it('grabando: muestra el aviso y el guion; sonando o sin grabación, no', () => {
    const activa = recording => ({
      'whatsappCalls/getActive': { id: 5, status: 'in_progress', recording },
    });
    const grabando = montar(activa(true));
    expect(grabando.vm.isRecording).toBe(true);
    expect(grabando.html()).toContain('WHATSAPP_CALLS.WIDGET.RECORDING_SCRIPT');

    expect(montar(activa(false)).vm.isRecording).toBe(false);
    expect(
      montar({
        'whatsappCalls/getActive': {
          id: 5,
          status: 'ringing',
          recording: true,
        },
      }).vm.isRecording
    ).toBe(false);
  });

  it('los avisos del store se muestran traducidos', async () => {
    const wrapper = montar();
    wrapper.vm.$options.watch.notice.call(wrapper.vm, {
      key: 'WHATSAPP_CALLS.WIDGET.BUSY',
      args: {},
    });
    expect(useAlert).toHaveBeenCalledWith('WHATSAPP_CALLS.WIDGET.BUSY');
  });
});

describe('Botón Llamar', () => {
  const montar = (getters, conversation = { id: 9, inbox_id: 3 }) =>
    shallowMount(WhatsappCallButton, {
      propsData: { conversation },
      mocks: { $t: clave => clave, $store: store(getters) },
      stubs: ['woot-button'],
    });

  it('aparece si la bandeja permite salientes', () => {
    expect(montar().vm.canCall).toBe(true);
    expect(
      montar({
        'inboxes/getInbox': () => ({ whatsapp_calls: { outbound: false } }),
      }).vm.canCall
    ).toBe(false);
    expect(montar({ 'inboxes/getInbox': () => ({}) }).vm.canCall).toBe(false);
  });

  it('se desactiva si ya hay una llamada', () => {
    expect(montar({ 'whatsappCalls/getActive': { id: 1 } }).vm.isBusy).toBe(
      true
    );
  });
});
