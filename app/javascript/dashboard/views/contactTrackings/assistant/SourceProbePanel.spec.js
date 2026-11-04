import { shallowMount } from '@vue/test-utils';
import AssistantAPI from 'dashboard/api/assistant';
import SourceProbePanel from './SourceProbePanel.vue';

vi.mock('dashboard/api/assistant', () => ({
  default: { sourceProbe: vi.fn(), sourceProbeRun: vi.fn() },
}));

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const DIRECTIVAS = [
  {
    directive: '{{hoja_buscar: Precios | Producto=? | Precio}}',
    kind: 'sheet_lookup',
    routes: ['precios'],
    ready: true,
  },
  {
    directive: '@buscar_predefinidas(PATITAS)',
    kind: 'similarity',
    routes: ['dudas', 'otra'],
    ready: true,
  },
];

const RESULTADO = {
  kind: 'similarity',
  threshold: 0.45,
  threshold_from: 'group',
  max_results: 3,
  used: 1,
  results: [
    { title: 'PATITAS_CONSULTA', similarity: 0.71, used: true, weak: false },
    {
      title: 'PATITAS_HORARIO',
      similarity: 0.4,
      used: false,
      reason: 'below_threshold',
      weak: true,
    },
  ],
};

const montar = async () => {
  const wrapper = shallowMount(SourceProbePanel, {
    propsData: { draft: '@ruta(x: y): @buscar_predefinidas(PATITAS)' },
    mocks: { $t: (c, a) => (a ? `${c} ${JSON.stringify(a)}` : c) },
    stubs: { 'woot-button': true },
  });
  await wrapper.setProps({ active: true });
  await flushPromises();
  return wrapper;
};

describe('SourceProbePanel', () => {
  beforeEach(() => {
    AssistantAPI.sourceProbe.mockResolvedValue({
      data: { directives: DIRECTIVAS },
    });
    AssistantAPI.sourceProbeRun.mockResolvedValue({ data: RESULTADO });
  });

  it('al entrar lee las fuentes del borrador y elige la primera que se puede probar', async () => {
    const wrapper = await montar();

    expect(AssistantAPI.sourceProbe).toHaveBeenCalledWith(
      '@ruta(x: y): @buscar_predefinidas(PATITAS)'
    );
    expect(wrapper.vm.selected).toBe(1);
    expect(wrapper.vm.optionLabel(DIRECTIVAS[1])).toContain('dudas, otra');
  });

  it('prueba la frase, muestra el umbral que usa y por qué quedó fuera cada una', async () => {
    const wrapper = await montar();
    wrapper.vm.phrase = '¿cuánto cuesta?';
    await wrapper.vm.run();
    await flushPromises();

    expect(AssistantAPI.sourceProbeRun).toHaveBeenCalledWith(
      '@buscar_predefinidas(PATITAS)',
      '¿cuánto cuesta?'
    );
    const texto = wrapper.text();
    expect(texto).toContain('"threshold":0.45');
    expect(texto).toContain('TRACKING_ASSISTANT_VIEW.PROBE.FROM_GROUP');
    expect(texto).toContain('PROBE.USED');
    expect(texto).toContain('PROBE.REASON_BELOW_THRESHOLD');
    expect(wrapper.vm.history).toEqual(['¿cuánto cuesta?']);
  });

  it('una hoja exacta avisa que su prueba llega después, sin pedir frase', async () => {
    const wrapper = await montar();
    wrapper.vm.selected = 0;
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('PROBE.KIND_SHEET_LOOKUP');
    expect(wrapper.find('#probe-phrase').exists()).toBe(false);
  });

  it('el error del servidor se dice en palabras', async () => {
    AssistantAPI.sourceProbeRun.mockRejectedValue({
      response: { data: { error: 'no_phrase' } },
    });
    const wrapper = await montar();
    wrapper.vm.phrase = 'x';
    await wrapper.vm.run();
    await flushPromises();

    expect(wrapper.text()).toContain('PROBE.ERROR_NO_PHRASE');
  });
});
