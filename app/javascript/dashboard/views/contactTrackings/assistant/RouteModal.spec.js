import { shallowMount } from '@vue/test-utils';
import RouteModal from './RouteModal.vue';

const montar = props =>
  shallowMount(RouteModal, {
    propsData: { show: false, ...props },
    mocks: { $t: c => c },
    stubs: { 'woot-modal': { template: '<div><slot /></div>' } },
  });

const escribir = async (wrapper, texto) => {
  const campo = wrapper.find('#route-scope');
  campo.element.value = texto;
  campo.element.setSelectionRange(texto.length, texto.length);
  await campo.trigger('input');
};

describe('RouteModal — «%» en el alcance', () => {
  it('abre los datos fijos y cambia el «%» por la cita', async () => {
    const wrapper = montar({ constantNames: ['Q1', 'EMPRESA'] });
    await wrapper.setProps({ show: true });

    await escribir(wrapper, 'Pregunta %');
    const lista = wrapper.findComponent({ name: 'ConstantPicker' });
    expect(lista.exists()).toBe(true);

    lista.vm.$emit('pick', 'Q1');
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.scope).toBe('Pregunta %Q1%');
    expect(wrapper.findComponent({ name: 'ConstantPicker' }).exists()).toBe(
      false
    );
  });

  it('un porcentaje o un agente sin datos fijos no abre nada', async () => {
    const conDatos = montar({ constantNames: ['Q1'] });
    await conDatos.setProps({ show: true });
    await escribir(conDatos, 'descuento del 30%');
    expect(conDatos.findComponent({ name: 'ConstantPicker' }).exists()).toBe(
      false
    );

    const sinDatos = montar();
    await sinDatos.setProps({ show: true });
    await escribir(sinDatos, 'Pregunta %');
    expect(sinDatos.findComponent({ name: 'ConstantPicker' }).exists()).toBe(
      false
    );
  });
});
