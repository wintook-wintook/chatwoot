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

    expect(wrapper.text()).toContain('17 / 2,000');
    expect(wrapper.text()).toContain('CANNED_MGMT.AUDIT.METER.OK');
    expect(wrapper.find('button').exists()).toBe(false);
  });

  it('pasado el tope avisa y enseña los bloques con su tamaño', async () => {
    const wrapper = montar({
      shortCode: 'Larga',
      content: `${'a'.repeat(1500)}\n\n${'b'.repeat(600)}`,
    });

    expect(wrapper.text()).toContain('CANNED_MGMT.AUDIT.METER.OVER');
    await wrapper.find('button').trigger('click');

    const bloques = wrapper.findAll('li');
    expect(bloques).toHaveLength(2);
    expect(bloques.at(0).text()).toContain('1,507');
    expect(bloques.at(1).text()).toContain('600');
  });
});
