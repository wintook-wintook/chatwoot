import { shallowMount } from '@vue/test-utils';
import VoiceCall from '../VoiceCall.vue';

const montar = data =>
  shallowMount(VoiceCall, {
    propsData: { data },
    mocks: {
      $t: (clave, args) => (args ? `${clave}:${JSON.stringify(args)}` : clave),
    },
  });

describe('Burbuja de llamada de WhatsApp', () => {
  it('una entrante sin contestar es «perdida»', () => {
    const wrapper = montar({ call_direction: 'inbound', status: 'no-answer' });
    expect(wrapper.vm.statusKey).toBe('MISSED');
  });

  it('una saliente sin respuesta es «sin respuesta», con su flecha hacia afuera', () => {
    const wrapper = montar({ call_direction: 'outbound', status: 'no-answer' });
    expect(wrapper.vm.statusKey).toBe('NO_ANSWER');
    expect(wrapper.vm.arrowIcon).toBe('arrow-up-right');
  });

  it('muestra la duración y quién la atendió', () => {
    const wrapper = montar({
      call_direction: 'inbound',
      status: 'completed',
      duration_seconds: 125,
      accepted_by: { id: 1, name: 'Ana' },
    });
    expect(wrapper.vm.duration).toBe('02:05');
    expect(wrapper.text()).toContain(
      'WHATSAPP_CALLS.BUBBLE.HANDLED_BY:{"name":"Ana"}'
    );
  });
});
