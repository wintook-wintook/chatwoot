import { shallowMount } from '@vue/test-utils';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import DraftingSketch from './DraftingSketch.vue';

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

vi.mock('dashboard/api/trackingTemplates', () => ({
  default: { trainingPreview: vi.fn() },
}));

const BLOQUES = {
  blocks: [
    {
      type: 'routes',
      text: '',
      lines: [
        { kind: 'route', name: 'cotizar', description: 'cuánto cuesta' },
        { kind: 'default', name: 'cotizar' },
      ],
    },
  ],
};

const montar = props =>
  shallowMount(DraftingSketch, {
    propsData: props,
    mocks: { $t: c => c },
    stubs: ['AgentDiagram'],
  });

describe('DraftingSketch', () => {
  beforeEach(() => {
    TrackingTemplatesAPI.trainingPreview.mockResolvedValue({
      data: { training_structure: BLOQUES },
    });
  });

  it('dibuja el boceto con la estructura que arma el backend', async () => {
    const wrapper = montar({ routes: '@ruta(cotizar: cuánto cuesta): -' });
    await flushPromises();
    expect(TrackingTemplatesAPI.trainingPreview).toHaveBeenCalledWith({
      text: '@ruta(cotizar: cuánto cuesta): -',
    });
    expect(wrapper.vm.structure).toEqual(BLOQUES);
  });

  it('elegir una frase ilumina la ruta a la que cayó', async () => {
    const wrapper = montar({
      routes: '@ruta(cotizar: x): -',
      tests: [
        { frase: 'precio de la grúa', cae_en: 'cotizar', estable: true },
        { frase: 'hola', cae_en: 'cotizar', estable: false },
      ],
    });
    await flushPromises();
    expect(wrapper.vm.diagramTest).toBeNull();
    wrapper.vm.toggle(0);
    expect(wrapper.vm.diagramTest).toEqual({
      mode: 'dry',
      result: { routes: { chosen: 'cotizar', default: 'cotizar' } },
    });
    expect(wrapper.vm.stableCount).toBe(1);
    wrapper.vm.toggle(0);
    expect(wrapper.vm.diagramTest).toBeNull();
  });

  it('sin boceto no llama al backend', async () => {
    montar({ routes: '' });
    await flushPromises();
    expect(TrackingTemplatesAPI.trainingPreview).not.toHaveBeenCalled();
  });
});
