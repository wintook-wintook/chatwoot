import { shallowMount } from '@vue/test-utils';
import CannedResponseFixAPI from 'dashboard/api/cannedResponseFix';
import FixModal from '../FixModal.vue';

vi.mock('dashboard/api/cannedResponseFix', () => ({
  default: {
    latest: vi.fn(),
    propose: vi.fn(),
    forFinding: vi.fn(),
    resolvePreview: vi.fn(),
    create: vi.fn(),
    status: vi.fn(),
    check: vi.fn(),
    apply: vi.fn(),
    discard: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve, 0);
  });

const respuesta = {
  id: 7,
  short_code: 'Guía',
  content: 'x'.repeat(2500),
  agent_chars: 2506,
};
const partes = [
  { short_code: 'Guía — Uno', content: 'Paso 1' },
  { short_code: 'Guía — Dos', content: 'Paso 2' },
];
const candados = (extra = {}) => ({
  size: { ok: true, max: 2000, parts: [{ chars: 16 }, { chars: 16 }] },
  data: { ok: true, total: 3, missing: [] },
  groups: { ok: true, prefixes: [], bad: [] },
  names: { ok: true, bad: [] },
  coverage: { ok: true, lines: 4, dropped: [], dropped_count: 0 },
  blocking: [],
  ...extra,
});
const propuesta = (checks = candados()) => ({
  id: 3,
  status: 'proposed',
  stale: false,
  proposal: {
    action: 'split',
    shape: 'procedure',
    subject: 'Guía',
    parts: partes,
    questions: [],
    cleanup: { removed: [], chars_before: 2506, chars_after: 2506 },
  },
  checks,
  original: respuesta,
});

const montar = (target = { kind: 'oversize', response: respuesta }) =>
  shallowMount(FixModal, {
    propsData: { show: true, target },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
      $te: () => true,
    },
    stubs: {
      'woot-modal': { template: '<div><slot /></div>' },
      'woot-button': {
        props: ['isDisabled'],
        template:
          '<button :disabled="isDisabled" @click="$emit(\'click\')"><slot /></button>',
      },
      'woot-loading-state': true,
      CharMeter: true,
    },
    directives: { tooltip: {} },
  });

// proyecto@arreglar_predefinidas — el modal «Arreglar con IA».
describe('FixModal', () => {
  beforeEach(() => vi.clearAllMocks());

  it('sin propuesta, ofrece pedirla y la consulta mientras corre', async () => {
    vi.useFakeTimers();
    CannedResponseFixAPI.latest.mockResolvedValue({ data: null });
    CannedResponseFixAPI.propose.mockResolvedValue({
      data: { id: 3, status: 'running', proposal: {}, checks: {} },
    });
    CannedResponseFixAPI.status.mockResolvedValue({ data: propuesta() });
    const wrapper = montar();
    await vi.runOnlyPendingTimersAsync();

    expect(wrapper.text()).toContain('CANNED_MGMT.FIX.PROPOSE');
    await wrapper.vm.propose();
    expect(wrapper.text()).toContain('CANNED_MGMT.FIX.RUNNING');

    await vi.advanceTimersByTimeAsync(3000);
    expect(CannedResponseFixAPI.status).toHaveBeenCalledWith(3);
    expect(wrapper.vm.parts).toHaveLength(2);
    vi.useRealTimers();
  });

  it('enseña las partes editables y aplica lo editado', async () => {
    CannedResponseFixAPI.latest.mockResolvedValue({ data: propuesta() });
    CannedResponseFixAPI.apply.mockResolvedValue({ data: {} });
    const wrapper = montar();
    await flushPromises();

    expect(wrapper.findAll('textarea')).toHaveLength(2);
    await wrapper
      .findAll('input[type="text"]')
      .at(0)
      .setValue('Guía — Primero');
    expect(wrapper.vm.dirty).toBe(true);

    await wrapper.vm.apply();
    expect(CannedResponseFixAPI.apply).toHaveBeenCalledWith(
      3,
      [{ short_code: 'Guía — Primero', content: 'Paso 1' }, partes[1]],
      false
    );
    expect(wrapper.emitted('applied')).toBeTruthy();
  });

  it('si falta un dato no deja aceptar hasta confirmar que ya no aplica', async () => {
    const faltan = candados({
      data: {
        ok: false,
        total: 3,
        missing: [{ kind: 'money', text: '$1,500' }],
      },
      blocking: ['data'],
    });
    CannedResponseFixAPI.latest.mockResolvedValue({ data: propuesta(faltan) });
    const wrapper = montar();
    await flushPromises();

    expect(wrapper.text()).toContain('$1,500');
    expect(wrapper.vm.cannotApply).toBe(true);
    await wrapper.setData({ force: true });
    expect(wrapper.vm.cannotApply).toBe(false);
  });

  it('el tamaño bloquea aunque se marque force', async () => {
    const grande = candados({
      size: { ok: false, max: 2000, parts: [{ chars: 2300 }, { chars: 16 }] },
      blocking: ['size'],
    });
    CannedResponseFixAPI.latest.mockResolvedValue({ data: propuesta(grande) });
    const wrapper = montar();
    await flushPromises();

    await wrapper.setData({ force: true });
    expect(wrapper.vm.cannotApply).toBe(true);
  });

  it('volver a comprobar manda las partes editadas', async () => {
    CannedResponseFixAPI.latest.mockResolvedValue({ data: propuesta() });
    CannedResponseFixAPI.check.mockResolvedValue({ data: candados() });
    const wrapper = montar();
    await flushPromises();

    wrapper.vm.removePart(1);
    await wrapper.vm.recheck();

    expect(CannedResponseFixAPI.check).toHaveBeenCalledWith(3, [partes[0]]);
    expect(wrapper.vm.dirty).toBe(false);
  });

  it('contradicción: no deja proponer hasta elegir el dato correcto y manda lo elegido', async () => {
    const hallazgo = {
      id: 9,
      kind: 'contradiction',
      details: {
        contradictions: [
          {
            topic: 'precio',
            quote_a: 'Cuesta $1,500',
            quote_b: 'Cuesta $1,800',
          },
        ],
      },
      responses: [
        { id: 1, short_code: 'A', content: 'Cuesta $1,500', agent_chars: 16 },
        { id: 2, short_code: 'B', content: 'Cuesta $1,800', agent_chars: 16 },
      ],
    };
    CannedResponseFixAPI.forFinding.mockResolvedValue({ data: null });
    CannedResponseFixAPI.resolvePreview.mockResolvedValue({
      data: {
        forbidden: [],
        required: [],
        also_in: [{ id: 5, short_code: 'Otra', matches: ['$1,800'] }],
      },
    });
    CannedResponseFixAPI.create.mockResolvedValue({
      data: { id: 4, status: 'running', proposal: {}, checks: {} },
    });
    const wrapper = montar({ kind: 'resolve', finding: hallazgo });
    await flushPromises();

    expect(wrapper.vm.choicesComplete).toBe(false);
    await wrapper.find('input[value="a"]').setChecked();
    expect(wrapper.vm.choicesComplete).toBe(true);

    await wrapper.vm.loadPreview();
    wrapper.vm.toggleExtra(5);
    await wrapper.vm.propose();

    expect(CannedResponseFixAPI.create).toHaveBeenCalledWith({
      kind: 'resolve',
      findingId: 9,
      choices: [{ choice: 'a', value: '' }],
      extraIds: [5],
    });
  });
});
