import { shallowMount } from '@vue/test-utils';
import DraftingFields from './DraftingFields.vue';

const montar = proposal =>
  shallowMount(DraftingFields, {
    propsData: { proposal },
    mocks: { $t: (c, a) => (a ? `${c} ${JSON.stringify(a)}` : c) },
    stubs: {
      'woot-button': {
        template: '<button @click="$emit(\'click\')"><slot /></button>',
      },
    },
  });

const PROPUESTA = {
  name: 'Demo',
  objective: 'Agendar demos',
  variables: 'SISTEMA = CONTPAQi | Aspel',
  datos_fijos:
    'EMPRESA = Kontrolya\nQ1 (pregunta) = ¿Qué usas? → guarda en SISTEMA',
};

describe('DraftingFields', () => {
  it('muestra lo que llenó la conversación', () => {
    const texto = montar(PROPUESTA).text();

    expect(texto).toContain('Agendar demos');
    expect(texto).toContain('CONTPAQi · Aspel');
    expect(texto).toContain('«¿Qué usas?»');
    expect(texto).toContain('→ SISTEMA');
  });

  it('sin nada, invita a conversar', () => {
    expect(montar(null).text()).toContain('FIELDS_EMPTY');
  });

  it('cada modal le pasa al de Datos fijos las variables y emite el texto', async () => {
    const wrapper = montar(PROPUESTA);
    const modal = wrapper.findComponent({ name: 'ConstantsModal' });
    expect(modal.props('variables')).toEqual(['SISTEMA']);

    modal.vm.$emit('save', {
      constants: [{ name: 'EMPRESA', type: 'texto', value: 'K', savesTo: '' }],
      extra: [],
    });
    wrapper.findComponent({ name: 'VariablesModal' }).vm.$emit('save', {
      variables: [{ name: 'ETAPA', options: ['A'], free: false, initial: '' }],
      extra: [],
    });
    wrapper
      .findComponent({ name: 'DefinitionModal' })
      .vm.$emit('save', { objective: 'Otro', ai_context: '' });

    expect(wrapper.emitted('update')).toEqual([
      [{ datos_fijos: 'EMPRESA = K' }],
      [{ variables: 'ETAPA = A' }],
      [{ objective: 'Otro', ai_context: '' }],
    ]);
  });

  it('elimina una variable o un dato fijo y emite el texto que queda', () => {
    const wrapper = montar(PROPUESTA);
    wrapper.vm.removeConstant(0);
    wrapper.vm.removeVariable(0);

    expect(wrapper.emitted('update')).toEqual([
      [{ datos_fijos: 'Q1 (pregunta) = ¿Qué usas? → guarda en SISTEMA' }],
      [{ variables: '' }],
    ]);
  });

  it('Agregar abre el modal con un renglón nuevo', async () => {
    const wrapper = montar(PROPUESTA);
    wrapper.vm.open('variables', 'new');
    await wrapper.vm.$nextTick();
    const modal = wrapper.findComponent({ name: 'VariablesModal' });
    expect(modal.props('show')).toBe(true);
    expect(modal.props('focus')).toBe('new');
  });
});
