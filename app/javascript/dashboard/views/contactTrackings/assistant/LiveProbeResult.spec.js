import { shallowMount } from '@vue/test-utils';
import LiveProbeResult from './LiveProbeResult.vue';

const montar = result =>
  shallowMount(LiveProbeResult, {
    propsData: { result },
    mocks: { $t: (c, a) => (a ? `${c} ${JSON.stringify(a)}` : c) },
  });

describe('LiveProbeResult', () => {
  it('foro: cómo buscó, los temas con su liga y cuáles tomaría', () => {
    const wrapper = montar({
      kind: 'live',
      service: 'forum',
      status: 'ok',
      mode: 'keyword',
      terms: ['timbrar factura'],
      max_results: 3,
      results: [
        { title: 'Timbrado', url: 'https://f/t/1', excerpt: 'x', used: true },
        { title: 'Otro', url: 'https://f/t/2', excerpt: 'y', used: false },
      ],
    });
    const texto = wrapper.text();

    expect(texto).toContain('PROBE.FORUM_KEYWORD');
    expect(texto).toContain('"terms":"timbrar factura"');
    expect(
      wrapper.findAll('a').wrappers.map(a => a.attributes('href'))
    ).toEqual(['https://f/t/1', 'https://f/t/2']);
    expect(texto).toContain('PROBE.USED');
    expect(texto).toContain('PROBE.REASON_OVER_LIMIT');
  });

  it('CONTPAQi: la respuesta tal cual y sus fuentes', () => {
    const wrapper = montar({
      kind: 'live',
      service: 'contpaq',
      status: 'ok',
      answer: 'Ve a Configuración',
      sources: [
        { title: 'Manual', url: 'https://m' },
        { title: 'Sin liga', url: '' },
      ],
    });

    expect(wrapper.text()).toContain('Ve a Configuración');
    expect(wrapper.text()).toContain('Sin liga');
    expect(wrapper.findAll('a')).toHaveLength(1);
  });

  it('sin resultados o sin respuesta lo dice', () => {
    expect(
      montar({ kind: 'live', service: 'forum', status: 'no_results' }).text()
    ).toContain('PROBE.FORUM_NO_RESULTS');
    expect(
      montar({
        kind: 'live',
        service: 'contpaq',
        status: 'no_answer',
        reason: 'unavailable',
      }).text()
    ).toContain('"reason":"unavailable"');
  });
});
