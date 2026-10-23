import { shallowMount } from '@vue/test-utils';
import AgentVersions from './AgentVersions.vue';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';

vi.mock('dashboard/api/trackingTemplates', () => ({
  default: {
    getVersions: vi.fn(),
    getVersion: vi.fn(),
    restoreVersion: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const VERSIONES = [
  {
    id: 12,
    version: 3,
    source: 'assistant',
    note: 'Agregó la ruta garantías',
    changed_fields: ['complementary_prompt'],
  },
  { id: 11, version: 2, source: 'manual', changed_fields: ['objective'] },
  { id: 10, version: 1, source: 'baseline', changed_fields: [] },
];

const esperar = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const montar = (canRestore = true) =>
  shallowMount(AgentVersions, {
    propsData: { templateId: 7, canRestore },
    mocks: {
      $t: (clave, args) => (args ? `${clave}:${JSON.stringify(args)}` : clave),
    },
    stubs: ['woot-button', 'woot-confirm-modal'],
  });

describe('AgentVersions', () => {
  beforeEach(() => {
    TrackingTemplatesAPI.getVersions.mockResolvedValue({
      data: { versions: VERSIONES },
    });
  });

  it('lista las versiones del agente y marca la más nueva como activa', async () => {
    const wrapper = montar();
    await esperar();
    expect(TrackingTemplatesAPI.getVersions).toHaveBeenCalledWith(7);
    expect(wrapper.vm.latestVersion).toBe(3);
    expect(wrapper.vm.sourceLabel('assistant')).toBe(
      'TRACKING_TEMPLATES.WORKSPACE.VERSIONS.SOURCE.ASSISTANT'
    );
  });

  it('muestra el diff por campo contra la anterior o contra la elegida', async () => {
    TrackingTemplatesAPI.getVersion.mockResolvedValue({
      data: {
        diff: [{ field: 'objective', from: 'Cobrar', to: 'Cobrar y agendar' }],
      },
    });
    const wrapper = montar();
    await esperar();

    await wrapper.vm.toggle(VERSIONES[1]);
    expect(TrackingTemplatesAPI.getVersion).toHaveBeenLastCalledWith(
      7,
      11,
      null
    );
    expect(wrapper.vm.fields[0].stats).toEqual({ added: 1, removed: 1 });
    expect(wrapper.vm.compareOptions.map(v => v.id)).toEqual([12, 10]);

    wrapper.vm.compareWith = 10;
    await wrapper.vm.loadDetail();
    expect(TrackingTemplatesAPI.getVersion).toHaveBeenLastCalledWith(7, 11, 10);
  });

  it('restaurar pide confirmación, recarga y avisa al espacio', async () => {
    TrackingTemplatesAPI.restoreVersion.mockResolvedValue({
      data: { version: 4 },
    });
    const wrapper = montar();
    await esperar();
    wrapper.vm.$refs.restoreDialog = {
      showConfirmation: vi.fn().mockResolvedValue(true),
    };

    await wrapper.vm.askRestore(VERSIONES[2]);

    expect(TrackingTemplatesAPI.restoreVersion).toHaveBeenCalledWith(7, 10);
    expect(wrapper.emitted('restored')).toBeTruthy();
  });

  it('sin permiso de admin no aparece Restaurar', async () => {
    const conPermiso = montar(true);
    const sinPermiso = montar(false);
    await esperar();
    expect(conPermiso.findAll('[icon="arrow-clockwise"]').length).toBe(2);
    expect(sinPermiso.findAll('[icon="arrow-clockwise"]').length).toBe(0);
  });

  it('si se cancela, no restaura', async () => {
    TrackingTemplatesAPI.restoreVersion.mockClear();
    const wrapper = montar();
    await esperar();
    wrapper.vm.$refs.restoreDialog = {
      showConfirmation: vi.fn().mockResolvedValue(false),
    };

    await wrapper.vm.askRestore(VERSIONES[2]);
    expect(TrackingTemplatesAPI.restoreVersion).not.toHaveBeenCalled();
  });
});
