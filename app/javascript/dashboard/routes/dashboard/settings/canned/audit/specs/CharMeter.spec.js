import { shallowMount } from '@vue/test-utils';
import CharMeter from '../CharMeter.vue';

const montar = props =>
  shallowMount(CharMeter, {
    propsData: props,
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
    },
  });

// proyecto@auditoria_predefinidas — el medidor del formulario.
describe('CharMeter', () => {
  it('cuenta el nombre y el contenido y dice que cabe', () => {
    const wrapper = montar({ shortCode: 'Horario', content: 'De 9 a 6' });

    expect(wrapper.text()).toContain('17 / 3,500');
    expect(wrapper.text()).toContain('CANNED_MGMT.AUDIT.METER.OK');
    expect(wrapper.find('button').exists()).toBe(false);
  });

  it('pasado el tope avisa y enseña los bloques con su tamaño', async () => {
    const wrapper = montar({
      shortCode: 'Larga',
      content: `${'a'.repeat(3000)}\n\n${'b'.repeat(600)}`,
    });

    expect(wrapper.text()).toContain('CANNED_MGMT.AUDIT.METER.OVER');
    await wrapper.find('button').trigger('click');

    const bloques = wrapper.findAll('li');
    expect(bloques).toHaveLength(2);
    expect(bloques.at(0).text()).toContain('3,007');
    expect(bloques.at(1).text()).toContain('600');
  });

  // proyecto@predefinidas_que_contestan: la pestaña Prompt, con su propio tope.
  it('mide el Prompt solo por su texto, con tope de 2,000 y sin bloques', () => {
    const wrapper = montar({ content: 'c'.repeat(2001), prompt: true });

    expect(wrapper.text()).toContain('2,001 / 2,000');
    expect(wrapper.text()).toContain('CANNED_MGMT.AUDIT.METER.PROMPT_OVER');
    expect(wrapper.find('button').exists()).toBe(false);
  });
});
