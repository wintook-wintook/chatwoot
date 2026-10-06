import { shallowMount } from '@vue/test-utils';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import trainingSectionsMixin from './trainingSectionsMixin';

vi.mock('dashboard/api/trackingTemplates', () => ({
  default: { trainingPreview: vi.fn(), getSectionTitles: vi.fn() },
}));

// Una pantalla mínima con el mixin: el texto es un dato y la vista, la de secciones.
const Pantalla = {
  mixins: [trainingSectionsMixin],
  data: () => ({
    trainingText: '',
    trainingView: 'sections',
    validation: null,
  }),
  render: h => h('div'),
};

const conCierre =
  '@ruta(info #info: x): @buscar_predefinidas -> @crear_ticket(tipo=Soporte)';
const sinCierre = conCierre.slice(0, -1);

describe('trainingSectionsMixin', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    TrackingTemplatesAPI.getSectionTitles.mockResolvedValue({ data: [] });
    TrackingTemplatesAPI.trainingPreview.mockImplementation(({ text }) =>
      Promise.resolve({
        data: {
          text,
          training_structure: { blocks: [] },
          validation: {
            blocking: text.endsWith(')') ? [] : [{ route: 'info' }],
          },
        },
      })
    );
  });
  afterEach(() => vi.useRealTimers());

  const esperar = async () => {
    await vi.runAllTimersAsync();
  };

  // 24/09/2026: al volver al texto con el que se cargó, el árbol no se revisaba y
  // se quedaba con el punto rojo de la revisión anterior.
  it('quitar el «)» y volver a ponerlo deja el árbol sin el aviso', async () => {
    const wrapper = shallowMount(Pantalla);
    wrapper.vm.trainingText = conCierre;
    wrapper.vm.loadTrainingFromText(conCierre);
    await esperar();

    wrapper.vm.trainingText = sinCierre;
    await esperar();
    expect(wrapper.vm.nodeIssues['route:info'].level).toBe('blocking');

    wrapper.vm.trainingText = conCierre;
    await esperar();
    expect(wrapper.vm.nodeIssues).toEqual({});
  });
});
