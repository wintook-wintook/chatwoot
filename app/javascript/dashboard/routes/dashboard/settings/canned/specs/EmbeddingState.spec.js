import { shallowMount } from '@vue/test-utils';
import EmbeddingState from '../EmbeddingState.vue';

const montar = item =>
  shallowMount(EmbeddingState, {
    propsData: { item },
    mocks: { $t: (c, a) => (a ? `${c} ${JSON.stringify(a)}` : c) },
    stubs: {
      'woot-button': {
        template: '<button @click="$emit(\'click\')"><slot /></button>',
      },
    },
  });

describe('EmbeddingState', () => {
  it('en la fuente de datos: sin botón', () => {
    const wrapper = montar({ id: 1, embedding_state: 'ready' });

    expect(wrapper.text()).toContain('EMBEDDING.STATE_READY');
    expect(wrapper.find('button').exists()).toBe(false);
  });

  it('sin OpenAI lo dice y no ofrece vectorizar', () => {
    const wrapper = montar({ id: 1, embedding_state: 'no_key' });

    expect(wrapper.text()).toContain('EMBEDDING.STATE_NO_KEY');
    expect(wrapper.find('button').exists()).toBe(false);
  });

  it('sin vector y con OpenAI ofrece vectorizar esa', async () => {
    const item = { id: 7, embedding_state: 'missing' };
    const wrapper = montar(item);

    await wrapper.find('button').trigger('click');
    expect(wrapper.text()).toContain('EMBEDDING.VECTORIZE');
    expect(wrapper.emitted('vectorize')).toEqual([[item]]);
  });

  it('si falló dice el motivo en palabras y ofrece reintentar', () => {
    const texto = montar({
      id: 1,
      embedding_state: 'stale',
      embedding_error: 'quota',
    }).text();

    expect(texto).toContain('EMBEDDING.STATE_STALE');
    expect(texto).toContain('EMBEDDING.ERROR_QUOTA');
    expect(texto).toContain('EMBEDDING.RETRY');
    expect(
      montar({
        id: 1,
        embedding_state: 'failed',
        embedding_error: 'http_400',
      }).text()
    ).toContain('EMBEDDING.ERROR_OTHER {"code":"http_400"}');
  });
});
