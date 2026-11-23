import { mount } from '@vue/test-utils';
import UploadPanel from './UploadPanel.vue';
import CollectionsAgentModal from '../readyAgents/CollectionsAgentModal.vue';
import { money } from './money';

const previewData = {
  headers: ['Num', 'Razón', 'Doc', 'Vence', 'Debe'],
  mapping: { customer_name: 'Razón', folio: 'Doc', due_on: 'Vence' },
  preview: {
    valid: 1,
    rows: 1,
    customers: 1,
    invoices: 1,
    aging: {},
    diff: {},
    errors: [],
  },
};
const preview = vi.fn(() => Promise.resolve({ data: previewData }));
vi.mock('dashboard/api/collections', () => ({
  default: { preview: (...a) => preview(...a) },
}));

const mocks = {
  $t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  $store: {
    getters: {
      'agents/getAgents': [],
      'teams/getTeams': [],
      'inboxes/getWhatsAppTemplates': () => [{ name: 'cobro' }],
    },
    dispatch: vi.fn(),
  },
};
const stubs = {
  WootButton: { template: '<button><slot /></button>' },
  WootModal: { template: '<div><slot /></div>' },
  WootModalHeader: true,
  WootTabs: { template: '<div><slot /></div>' },
  WootTabsItem: true,
  AgentBusiness: true,
  AgentVoice: true,
  FollowUpPlan: true,
  ReadyAgentChat: true,
};
const flush = () =>
  new Promise(r => {
    setTimeout(r);
  });

describe('Cobranza', () => {
  it('montos con formato de pesos', () => {
    expect(money(18500)).toBe('$18,500.00 MXN');
  });

  it('subir la cartera: lee el archivo, muestra las columnas y pide las obligatorias que falten', async () => {
    preview.mockImplementation(() => Promise.resolve({ data: previewData }));
    const w = mount(UploadPanel, { mocks, stubs });
    w.vm.onFile({ target: { files: [new File(['x'], 'mio.xlsx')] } });
    await flush();
    expect(w.vm.headers).toContain('Debe');
    expect(w.vm.missing).toEqual(['balance']);
    w.vm.setColumn('balance', 'Debe');
    expect(preview).toHaveBeenLastCalledWith(
      expect.any(File),
      expect.objectContaining({ balance: 'Debe' })
    );
    expect(w.vm.missing).toEqual([]);
  });

  it('el asistente del agente manda canal, plantillas por etapa y reglas de cobro', () => {
    const w = mount(CollectionsAgentModal, {
      propsData: {
        show: true,
        inboxes: [{ id: 3, name: 'WA', channel_type: 'Channel::Whatsapp' }],
      },
      mocks,
      stubs,
    });
    w.vm.form.name = 'Cobranza';
    w.vm.form.inbox_id = 3;
    w.vm.setTemplate('due', 'cobro');
    w.vm.form.settings.outreach_on = true;
    const body = w.vm.payload();
    expect(body).toMatchObject({
      kind: 'collections',
      channel: { inbox_id: 3 },
    });
    expect(body.settings).toMatchObject({
      outreach_on: true,
      templates: { due: 'cobro' },
      every_days: 7,
    });
    expect(w.vm.waTemplates).toEqual(['cobro']);
    expect(w.vm.canSave).toBe(true);
  });
});
