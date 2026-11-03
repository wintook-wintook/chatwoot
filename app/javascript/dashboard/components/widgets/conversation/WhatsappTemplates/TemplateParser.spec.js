import { shallowMount } from '@vue/test-utils';
import TemplateParser from './TemplateParser.vue';

// feat/plantillas_variables_resolver F9.3 — la plantilla llega llenada y se puede cambiar
const conNombres = {
  name: 'saludo',
  language: 'es_MX',
  category: 'UTILITY',
  components: [
    { type: 'BODY', text: 'Hola {{primer_nombre}}, tu plan es {{plan}}.' },
  ],
};
const numerada = {
  ...conNombres,
  components: [{ type: 'BODY', text: 'Hola {{1}}.' }],
};
const variableContext = {
  contact: { name: 'Juan Pérez', custom_attributes: {} },
};

const montar = propsData =>
  shallowMount(TemplateParser, {
    propsData: { template: conNombres, variableContext, ...propsData },
    mocks: { $t: clave => clave },
    stubs: ['woot-button', 'woot-input'],
  });

describe('TemplateParser', () => {
  it('llena lo que tiene el contacto y deja vacío lo demás', () => {
    expect(montar().vm.processedParams).toEqual({
      primer_nombre: 'Juan',
      plan: '',
    });
  });

  it('no deja mandar con un dato vacío', () => {
    const wrapper = montar();

    wrapper.vm.sendMessage();

    expect(wrapper.vm.errors).toEqual(['BODY']);
    expect(wrapper.emitted('sendMessage')).toBeUndefined();
  });

  it('manda lo que quede en el formulario, con su nombre', async () => {
    const wrapper = montar();
    wrapper.vm.processedParams.primer_nombre = 'Don Juan';
    wrapper.vm.processedParams.plan = 'Plus';
    await wrapper.vm.$nextTick();

    wrapper.vm.sendMessage();

    const [{ message, templateParams }] = wrapper.emitted('sendMessage')[0];
    expect(message).toBe('Hola Don Juan, tu plan es Plus.');
    expect(templateParams.processed_params).toEqual({
      primer_nombre: 'Don Juan',
      plan: 'Plus',
    });
  });

  it('las numeradas siguen vacías', () => {
    expect(montar({ template: numerada }).vm.processedParams).toEqual({
      1: '',
    });
  });
});
