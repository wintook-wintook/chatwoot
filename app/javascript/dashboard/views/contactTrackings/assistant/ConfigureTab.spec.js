import { shallowMount } from '@vue/test-utils';
import ConfigureTab from './ConfigureTab.vue';
import AssistantAPI from 'dashboard/api/assistant';

vi.mock('dashboard/api/assistant', () => ({
  default: { suggestVariables: vi.fn(), markVariables: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const FORO_OK = {
  key: 'knowledge_source:foro_sentidos',
  group: 'sources',
  kind: 'knowledge_source',
  name: 'Foro_Sentidos',
  wrote: '@buscar_foro(Foro_Sentidos)',
  status: 'ok',
  fix: 'create_inline',
  create: { source_type: 'discourse', name: 'Foro_Sentidos' },
  options: ['Foro_Sentidos', 'Foro_Ventas'],
};
const DOC_FALTA = {
  key: 'google_doc:precios',
  group: 'sources',
  kind: 'google_doc',
  name: 'Precios',
  wrote: '{{doc:Precios}}',
  status: 'missing',
  fix: 'create_inline',
  create: { source_type: 'google_doc', name: 'Precios' },
  options: ['Lista 2026'],
};

const montar = (draft, items = [FORO_OK, DOC_FALTA]) =>
  shallowMount(ConfigureTab, {
    propsData: { items, draft },
    mocks: {
      $t: clave => clave,
      $store: { getters: { getCurrentAccountId: 1 } },
    },
    stubs: ['woot-button', 'AddSourceModal'],
  });

const esperar = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

describe('ConfigureTab', () => {
  beforeEach(() => {
    AssistantAPI.suggestVariables.mockReset();
    AssistantAPI.suggestVariables.mockResolvedValue({
      data: { variables: [{ text: 'Sentidos Creativos', label: 'Nombre' }] },
    });
  });

  it('muestra lo que ya existe junto a lo que falta (primero lo que falta)', () => {
    const wrapper = montar('texto A');
    const fuentes = wrapper.vm.groups.find(g => g.group === 'sources');
    expect(fuentes.items.map(i => i.key)).toEqual([DOC_FALTA.key, FORO_OK.key]);
  });

  it('para cambiar lo que ya existe no ofrece el mismo nombre', () => {
    const wrapper = montar('texto B');
    expect(wrapper.vm.optionsFor(FORO_OK)).toEqual(['Foro_Ventas']);
    expect(wrapper.vm.optionsFor(DOC_FALTA)).toEqual(['Lista 2026']);
    expect(wrapper.vm.selectPlaceholder(FORO_OK)).toBe(
      'TRACKING_ASSISTANT_VIEW.CONFIGURE.CHANGE_TO'
    );
  });

  it('«Crear otra» abre el modal en blanco y conserva la respuesta elegida', async () => {
    const wrapper = montar('texto C');
    wrapper.vm.setAnswer(FORO_OK.key, 'Foro_Ventas');
    wrapper.vm.creatingSource = FORO_OK;
    expect(wrapper.vm.creatingInitial).toEqual({
      source_type: 'discourse',
      name: '',
    });

    await wrapper.setProps({ items: [{ ...FORO_OK }, DOC_FALTA] });
    expect(wrapper.vm.answers[FORO_OK.key]).toBe('Foro_Ventas');
  });

  it('busca datos de otro negocio sola al abrir y no repite con el mismo texto', async () => {
    const primera = montar('texto D');
    await esperar();
    expect(AssistantAPI.suggestVariables).toHaveBeenCalledTimes(1);
    expect(primera.vm.suggestions).toHaveLength(1);

    const segunda = montar('texto D');
    await esperar();
    expect(AssistantAPI.suggestVariables).toHaveBeenCalledTimes(1);
    expect(segunda.vm.suggestions).toHaveLength(1);

    montar('texto D cambiado');
    await esperar();
    expect(AssistantAPI.suggestVariables).toHaveBeenCalledTimes(2);
  });

  it('sin texto no llama a la IA', async () => {
    montar('   ');
    await esperar();
    expect(AssistantAPI.suggestVariables).not.toHaveBeenCalled();
  });

  it('un error de la IA se muestra en la pestaña, sin alerta', async () => {
    AssistantAPI.suggestVariables.mockResolvedValue({
      data: { error: 'no_api_key', variables: [] },
    });
    const wrapper = montar('texto E');
    await esperar();
    expect(wrapper.vm.suggestError).toBe('SUGGEST_ERROR_NO_API_KEY');
    expect(wrapper.vm.suggestions).toBeNull();
  });
});
