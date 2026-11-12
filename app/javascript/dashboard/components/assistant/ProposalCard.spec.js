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
