import { shallowMount } from '@vue/test-utils';
import ProposalCard from './ProposalCard.vue';

// Responder: la tarjeta dice en grande a quién va.
const mount = labels =>
  shallowMount(ProposalCard, {
    propsData: {
      proposal: {
        id: 'p1',
        type: 'reply',
        status: 'pending',
        payload: { conversation_id: 3, content: 'Sí, hoy' },
        labels,
      },
    },
    mocks: { $t: key => key, $te: () => true },
    stubs: { FluentIcon: true, WootButton: true },
  });

describe('ProposalCard — responder', () => {
  it('muestra a quién va y la conversación', () => {
    const wrapper = mount({
      to: 'Andrés Liverio',
      conversation: '#3 · Telegram · Andrés Liverio',
    });
    const to = wrapper.find('[data-test="reply-to"]');
    expect(to.text()).toContain('Andrés Liverio');
    expect(to.text()).toContain('#3 · Telegram');
  });
});

// Llamar por WhatsApp: al confirmar, la llamada sale del navegador (store whatsappCalls).
describe('ProposalCard — llamar por WhatsApp', () => {
  it('al confirmar inicia la llamada con lo que manda el servidor', async () => {
    const call = { id: 7, inbox_id: 2, meta: { sender: { name: 'Mario' } } };
    const dispatch = vi.fn();
    const wrapper = shallowMount(ProposalCard, {
      propsData: {
        proposal: {
          id: 'p2',
          type: 'whatsapp_call',
          status: 'pending',
          payload: { conversation_id: 7 },
          labels: { target: 'Mario', rows: [['PHONE', '+5215512345678']] },
        },
      },
      mocks: { $t: key => key, $te: () => true, $store: { dispatch } },
      stubs: { FluentIcon: true, WootButton: true },
    });
    expect(wrapper.find('[data-test="call-hint"]').exists()).toBe(true);

    wrapper.vm.startCall({ type: 'whatsapp_call', result: { call } });
    expect(dispatch).toHaveBeenCalledWith('whatsappCalls/call', call);

    dispatch.mockClear();
    wrapper.vm.startCall({ type: 'note', result: { label: 'x' } });
    expect(dispatch).not.toHaveBeenCalled();
  });
});
