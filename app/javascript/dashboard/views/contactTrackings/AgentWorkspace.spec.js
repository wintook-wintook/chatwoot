import { shallowMount } from '@vue/test-utils';
import AgentWorkspace from './AgentWorkspace.vue';

vi.mock('dashboard/api/trackingTemplates', () => ({
  default: {
    getVersions: vi
      .fn()
      .mockResolvedValue({ data: { versions: [{ version: 5 }] } }),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('./Assistant.vue', () => ({
  default: { name: 'Assistant', render: () => null },
}));
vi.mock(
  'dashboard/routes/dashboard/settings/trackingTemplates/EditTemplate.vue',
  () => ({
    default: {
      name: 'TemplateForm',
      props: { hideTraining: Boolean, templateData: Object, mode: String },
      render: () => null,
    },
  })
);

const TEMPLATE = { id: 7, name: 'Cobranza', inbox_name: 'Ventas WA' };

const montar = ({
  role = 'administrator',
  templateId = '7',
  query = {},
} = {}) => {
  const router = { push: vi.fn(), replace: vi.fn() };
  const wrapper = shallowMount(AgentWorkspace, {
    mocks: {
      $t: clave => clave,
      $route: { params: { templateId }, query },
      $router: router,
      $store: {
        dispatch: vi.fn(),
        getters: {
          getCurrentRole: role,
          'trackingTemplates/getTemplates': [TEMPLATE],
        },
      },
    },
    stubs: ['woot-button', 'woot-sidemenu-icon', 'AgentVersions'],
  });
  return { wrapper, router };
};

describe('AgentWorkspace', () => {
  it('un admin ve Entrenamiento, Pruebas, Ficha y Versiones, y entra al Entrenamiento', () => {
    const { wrapper } = montar();
    expect(wrapper.vm.sections.map(s => s.id)).toEqual([
      'training',
      'tests',
      'profile',
      'versions',
    ]);
    expect(wrapper.vm.section).toBe('training');
    expect(wrapper.vm.title).toBe('Cobranza');
    expect(wrapper.vm.inboxName).toBe('Ventas WA');
  });

  it('un agente no ve el Entrenamiento y entra a la Ficha', () => {
    const { wrapper } = montar({ role: 'agent' });
    expect(wrapper.vm.sections.map(s => s.id)).toEqual(['profile', 'versions']);
    expect(wrapper.vm.section).toBe('profile');
  });

  it('un agente nuevo solo tiene Entrenamiento y Pruebas', () => {
    const { wrapper } = montar({ templateId: 'new' });
    expect(wrapper.vm.templateId).toBeNull();
    expect(wrapper.vm.sections.map(s => s.id)).toEqual(['training', 'tests']);
  });

  // proyecto@diagrama_agente_ia: Pruebas es el mismo Asistente con otra vista.
  it('Entrenamiento y Pruebas comparten el Asistente sin volver a montarlo', async () => {
    const { wrapper } = montar();
    await wrapper.vm.$nextTick();
    const antes = wrapper.findComponent({ name: 'Assistant' });
    expect(antes.attributes('view')).toBe('training');

    antes.vm.$emit('openTests');
    await wrapper.vm.$nextTick();
    const despues = wrapper.findComponent({ name: 'Assistant' });
    expect(wrapper.vm.section).toBe('tests');
    expect(despues.attributes('view')).toBe('tests');
    expect(despues.vm).toBe(antes.vm);

    despues.vm.$emit('openTraining');
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.section).toBe('training');
  });

  it('respeta ?seccion= y ?session=', () => {
    const { wrapper } = montar({
      query: { seccion: 'versions', session: '41' },
    });
    expect(wrapper.vm.section).toBe('versions');
    expect(wrapper.vm.sessionId).toBe(41);
  });

  it('al publicar un agente nuevo, la ruta pasa a ese agente sin salir', () => {
    const { wrapper, router } = montar({ templateId: 'new' });
    wrapper.vm.goToAgent(9);
    expect(router.replace).toHaveBeenCalledWith({
      name: 'contact_trackings_agent',
      params: { templateId: '9' },
      query: { seccion: 'training' },
    });
  });

  it('en la Ficha, el admin no ve ni manda el Entrenamiento', async () => {
    const { wrapper } = montar({ query: { seccion: 'profile' } });
    await wrapper.vm.$nextTick();
    const ficha = wrapper.findComponent({ name: 'TemplateForm' });
    expect(ficha.props('hideTraining')).toBe(true);
  });
});
