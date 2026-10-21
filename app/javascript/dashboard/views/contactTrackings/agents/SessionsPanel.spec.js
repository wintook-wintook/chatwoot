import { shallowMount } from '@vue/test-utils';
import SessionsPanel from './SessionsPanel.vue';

vi.mock('dashboard/api/assistant', () => ({
  default: { getSessions: vi.fn().mockResolvedValue({ data: [] }) },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const montar = () =>
  shallowMount(SessionsPanel, {
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
    },
    stubs: ['woot-button', 'woot-confirm-modal', 'woot-loading-state'],
  });

const fila = ultima => ({
  id: 1,
  status: 'open',
  versions: ultima ? [ultima] : [],
});

describe('En construcción — Último cambio', () => {
  it('sin cambios, o recién abierto', () => {
    const vm = montar().vm;
    expect(vm.lastChange(fila(null))).toBe(
      'TRACKING_TEMPLATES.SESSIONS.NO_CHANGES'
    );
    expect(vm.lastChange(fila({ source: 'loaded' }))).toBe(
      'TRACKING_TEMPLATES.SESSIONS.NO_CHANGES'
    );
  });

  it('lo que declaró el Asistente, con su origen', () => {
    const vm = montar().vm;
    expect(
      vm.lastChange(
        fila({ source: 'assistant', summary: 'Agregó la ruta garantías' })
      )
    ).toBe(
      'TRACKING_ASSISTANT_VIEW.LOG_SOURCE_ASSISTANT: Agregó la ruta garantías'
    );
  });

  it('las notas de «Configurar», con cuántas más hay', () => {
    const vm = montar().vm;
    expect(
      vm.lastChange(
        fila({ source: 'configured', notes: ['A → B', 'C → D', 'E → F'] })
      )
    ).toBe(
      'TRACKING_ASSISTANT_VIEW.LOG_SOURCE_CONFIGURED: A → B · C → D TRACKING_TEMPLATES.SESSIONS.AND_MORE {"count":1}'
    );
  });

  it('a mano, las piezas tocadas', () => {
    const vm = montar().vm;
    expect(
      vm.lastChange(fila({ source: 'manual', changes: ['+ @ruta(soporte)'] }))
    ).toBe('TRACKING_ASSISTANT_VIEW.LOG_SOURCE_MANUAL: + @ruta(soporte)');
  });
});
