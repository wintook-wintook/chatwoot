// «Imágenes y archivos» de los Agentes listos: momentos por función, reglas y límites de WhatsApp.
import { shallowMount } from '@vue/test-utils';
import AgentFiles, { fileProblem, blankRule } from './AgentFiles.vue';

const mountFiles = props =>
  shallowMount(AgentFiles, {
    propsData: { value: {}, ...props },
    mocks: { $t: (x, p) => (p ? `${x} ${JSON.stringify(p)}` : x) },
    stubs: { FluentIcon: true },
  });

describe('AgentFiles', () => {
  it('cada función trae sus momentos', () => {
    expect(mountFiles({ kind: 'campaign_seller' }).vm.options).toEqual([
      'interest',
      'ask',
    ]);
    expect(
      mountFiles({ kind: 'campaign_seller', invite: true }).vm.options
    ).toContain('confirm');
    expect(mountFiles({ kind: 'prospects', booking: true }).vm.options).toEqual(
      ['ask', 'welcome', 'booking']
    );
    expect(mountFiles({ kind: 'customers' }).vm.options).toEqual([
      'ask',
      'tickets',
    ]);
  });

  it('cambia la regla de un archivo: descripción, momentos y toques', () => {
    const wrapper = mountFiles({
      kind: 'customers',
      touches: 2,
      value: { instructivo: blankRule() },
    });
    wrapper.vm.setRule('instructivo', 'about', 'Pasos para entrar');
    expect(wrapper.emitted('input')[0][0].instructivo.about).toBe(
      'Pasos para entrar'
    );
    wrapper.vm.toggle('instructivo', 'tickets');
    expect(wrapper.emitted('input')[1][0].instructivo.tickets).toEqual(['*']);
    wrapper.vm.toggleTouch('instructivo', 2);
    expect(wrapper.emitted('input')[2][0].instructivo.attempts).toEqual([2]);
  });

  it('solo deja lo que WhatsApp acepta', () => {
    const file = (type, mb) => ({ type, size: mb * 1024 * 1024 });
    expect(fileProblem(file('image/png', 1))).toBeNull();
    expect(fileProblem(file('image/webp', 1))).toBe('IMAGE_TYPE');
    expect(fileProblem(file('image/jpeg', 6))).toBe('TOO_BIG');
    expect(fileProblem(file('application/pdf', 50))).toBeNull();
    expect(fileProblem(file('video/mp4', 20))).toBe('TOO_BIG');
  });
});
