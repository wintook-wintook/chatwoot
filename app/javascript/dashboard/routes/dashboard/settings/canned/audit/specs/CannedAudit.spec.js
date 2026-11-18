import { shallowMount } from '@vue/test-utils';
import CannedResponseAuditAPI from 'dashboard/api/cannedResponseAudit';
import CannedAudit from '../CannedAudit.vue';

vi.mock('dashboard/api/cannedResponseAudit', () => ({
  default: {
    show: vi.fn(),
    run: vi.fn(),
    setStatus: vi.fn(),
    keep: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve, 0);
  });
// Con relojes falsos setTimeout no corre: solo se vacían las promesas pendientes.
const flushMicrotasks = async () => {
  for (let i = 0; i < 10; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    await Promise.resolve();
  }
};

const respuesta = (id, shortCode, content) => ({
  id,
  short_code: shortCode,
  content,
  agent_chars: shortCode.length + 2 + content.length,
});

const reporte = {
  summary: {
    oversize: 1,
    duplicate: 1,
    contradiction: 1,
    overlap: 0,
    writing: 0,
    dismissed: 0,
  },
  limits: { max: 2000, warn: 1600 },
  oversize: [
    {
      ...respuesta(9, 'Larga', 'x'.repeat(2100)),
      blocks: [{ chars: 2107, preview: 'Larga: xxx' }],
    },
  ],
  findings: [
    {
      id: 1,
      kind: 'contradiction',
      severity: 'high',
      status: 'open',
      similarity: 0.83,
      details: {
        contradictions: [
          {
            topic: 'precio',
            quote_a: 'Cuesta $1,500',
            quote_b: '<b>$1,800</b>',
            why: 'dos precios',
          },
        ],
      },
      responses: [
        respuesta(1, 'Precio', 'Cuesta $1,500 al mes.'),
        respuesta(2, 'Costo', 'La colegiatura es de <b>$1,800</b>.'),
      ],
    },
    {
      id: 2,
      kind: 'duplicate',
      severity: 'high',
      status: 'open',
      similarity: 0.97,
      details: {},
      responses: [
        respuesta(3, 'Formas', 'Lista'),
        respuesta(4, 'Formas 2', 'Lista'),
      ],
    },
  ],
  audit: {
    status: 'done',
    stats: { responses: 60, pairs: 30, failed_calls: 0 },
    finished_at: '2026-11-17T20:10:00Z',
  },
};

const montar = () =>
  shallowMount(CannedAudit, {
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
      $te: () => true,
    },
    stubs: {
      'woot-button': {
        template: '<button @click="$emit(\'click\')"><slot /></button>',
      },
      'woot-tabs': true,
      'woot-tabs-item': true,
      'woot-loading-state': true,
      'woot-delete-modal': true,
    },
  });

// proyecto@auditoria_predefinidas — la pestaña «Auditoría».
describe('CannedAudit', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CannedResponseAuditAPI.show.mockResolvedValue({ data: reporte });
  });

  it('enseña las que pasan el tope y los hallazgos', async () => {
    const wrapper = montar();
    await flushPromises();

    expect(CannedResponseAuditAPI.show).toHaveBeenCalledWith('open');
    expect(wrapper.text()).toContain('Larga');
    expect(wrapper.text()).toContain('CANNED_MGMT.AUDIT.KINDS.contradiction');
    expect(wrapper.text()).toContain('CANNED_MGMT.AUDIT.KINDS.duplicate');
  });

  it('marca las frases citadas y escapa el HTML del contenido', async () => {
    const wrapper = montar();
    await flushPromises();

    const html = wrapper.findAll('[class*="whitespace-pre-wrap"]');
    expect(html.at(0).html()).toContain('<mark');
    expect(html.at(0).html()).toContain('Cuesta $1,500</mark>');
    expect(html.at(1).html()).toContain('&lt;b&gt;$1,800&lt;/b&gt;</mark>');
    expect(html.at(1).html()).not.toContain('<b>');
  });

  it('las tarjetas filtran por tipo', async () => {
    const wrapper = montar();
    await flushPromises();

    await wrapper.setData({ filter: 'duplicate' });
    expect(wrapper.vm.findings.map(f => f.id)).toEqual([2]);
    expect(wrapper.vm.oversize).toEqual([]);

    await wrapper.setData({ filter: 'oversize' });
    expect(wrapper.vm.findings).toEqual([]);
    expect(wrapper.vm.oversize).toHaveLength(1);
  });

  it('descarta un hallazgo y recarga', async () => {
    CannedResponseAuditAPI.setStatus.mockResolvedValue({});
    const wrapper = montar();
    await flushPromises();

    await wrapper.vm.setStatus(reporte.findings[0], 'dismissed');

    expect(CannedResponseAuditAPI.setStatus).toHaveBeenCalledWith(
      1,
      'dismissed'
    );
    expect(CannedResponseAuditAPI.show).toHaveBeenCalledTimes(2);
  });

  it('en duplicadas conserva la elegida y elimina la otra', async () => {
    CannedResponseAuditAPI.keep.mockResolvedValue({});
    const wrapper = montar();
    await flushPromises();

    const duplicada = reporte.findings[1];
    wrapper.vm.askKeep(duplicada, duplicada.responses[1]);
    expect(wrapper.vm.confirmKeep.drop.id).toBe(3);
    await wrapper.vm.keep();

    expect(CannedResponseAuditAPI.keep).toHaveBeenCalledWith(2, 4);
  });

  it('mientras corre, vuelve a consultar', async () => {
    vi.useFakeTimers();
    CannedResponseAuditAPI.show.mockResolvedValue({
      data: { ...reporte, audit: { status: 'running', stats: {} } },
    });
    montar();
    await flushMicrotasks();

    vi.advanceTimersByTime(4000);
    await flushMicrotasks();
    expect(CannedResponseAuditAPI.show).toHaveBeenCalledTimes(2);
    vi.useRealTimers();
  });
});
