import { shallowMount } from '@vue/test-utils';
import CreateLabelButton from './CreateLabelButton.vue';
import { emitter } from 'shared/helpers/mitt';
import { ASSISTANT_SOURCES_CHANGED } from './sourceDirective';

const montar = tag =>
  shallowMount(CreateLabelButton, {
    propsData: { tag },
    mocks: { $t: clave => clave },
    stubs: ['woot-button', 'woot-modal'],
  });

describe('CreateLabelButton', () => {
  it('abre el modal de Ajustes con el nombre sin «#»', async () => {
    const wrapper = montar('#solicita_servicio');
    wrapper.vm.show = true;
    await wrapper.vm.$nextTick();

    expect(
      wrapper.findComponent({ name: 'AddLabel' }).props('prefillTitle')
    ).toBe('solicita_servicio');
  });

  it('al cerrar, el Asistente recarga el inventario y vuelve a comprobar', () => {
    const aviso = vi.fn();
    emitter.on(ASSISTANT_SOURCES_CHANGED, aviso);
    const wrapper = montar('reclamo');
    wrapper.vm.show = true;

    wrapper.vm.close();
    expect(aviso).toHaveBeenCalled();
    expect(wrapper.vm.show).toBe(false);
    emitter.off(ASSISTANT_SOURCES_CHANGED, aviso);
  });
});
