import { shallowMount } from '@vue/test-utils';
import AccountsTab from './AccountsTab.vue';
import IssueModal from './IssueModal.vue';
import PlanModal from './PlanModal.vue';
import SummaryTab from './SummaryTab.vue';
import LicensesAPI from 'dashboard/api/licenses';

// feat/licencias (F2b)
vi.mock('dashboard/api/licenses', () => ({
  default: {
    getAccounts: vi.fn(),
    issue: vi.fn(),
    createPlan: vi.fn(),
    getSummary: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const mocks = {
  $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
  $i18n: { locale: 'es' },
};
const stubs = [
  'woot-button',
  'woot-label',
  'woot-modal-header',
  'TableFooter',
  'Modal',
  'IssueModal',
  'HistoryModal',
];
const esperar = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const PLAN = {
  id: 3,
  name: 'Profesional',
  duration_days: 180,
  default_max_agents: 10,
  active: true,
  features: [],
};

describe('AccountsTab', () => {
  beforeEach(() => {
    LicensesAPI.getAccounts.mockReset();
    LicensesAPI.getAccounts.mockResolvedValue({
      data: { accounts: [], meta: { total: 0 } },
    });
  });

  it('pide la primera página con el filtro y los días', async () => {
    const wrapper = shallowMount(AccountsTab, { mocks, stubs });
    await esperar();
    wrapper.vm.estado = 'por_vencer';
    await esperar();

    expect(LicensesAPI.getAccounts).toHaveBeenLastCalledWith(
      expect.objectContaining({
        estado: 'por_vencer',
        dias: 7,
        page: 1,
        per_page: 25,
      })
    );
  });

  it('una licencia con 7 días o menos se marca por vencer', () => {
    const wrapper = shallowMount(AccountsTab, { mocks, stubs });
    const fila = days => ({
      license_state: 'paid',
      agents_count: 4,
      license: { days_left: days, max_agents: 5 },
    });

    expect(wrapper.vm.rowState(fila(30))).toBe('paid');
    expect(wrapper.vm.rowState(fila(5))).toBe('por_vencer');
    expect(wrapper.vm.stateScheme(fila(5))).toBe('warning');
    expect(wrapper.vm.agentsText(fila(30))).toBe('4 / 5');
    expect(
      wrapper.vm.rowState({ license_state: 'vencida', license: null })
    ).toBe('vencida');
  });
});

describe('IssueModal', () => {
  beforeEach(() => {
    LicensesAPI.issue.mockReset();
    LicensesAPI.issue.mockResolvedValue({ data: {} });
  });

  it('al elegir el plan precarga sus valores, y manda lo ajustado', async () => {
    const wrapper = shallowMount(IssueModal, {
      mocks,
      stubs,
      propsData: {
        account: { id: 9, name: 'Grúas', license: null },
        plans: [PLAN],
      },
    });
    wrapper.vm.form.license_plan_id = 3;
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.form).toMatchObject({
      name: 'Profesional',
      max_agents: 10,
      duration_days: 180,
      start: 'now',
    });

    wrapper.vm.form.max_agents = 12;
    await wrapper.vm.submit();

    expect(LicensesAPI.issue).toHaveBeenCalledWith(
      expect.objectContaining({
        target_account_id: 9,
        license_plan_id: 3,
        max_agents: 12,
        start: 'now',
      })
    );
    expect(wrapper.emitted('issued')).toBeTruthy();
  });

  it('con licencia vigente propone dejarla en cola', () => {
    const wrapper = shallowMount(IssueModal, {
      mocks,
      stubs,
      propsData: {
        account: { id: 9, name: 'Grúas', license: { id: 1 } },
        plans: [PLAN],
      },
    });
    expect(wrapper.vm.form.start).toBe('queue');
  });
});

describe('PlanModal', () => {
  it('separa canales de funciones', () => {
    const wrapper = shallowMount(PlanModal, {
      mocks,
      stubs,
      propsData: {
        plan: { id: null },
        availableFeatures: [
          'channel_whatsapp',
          'campaigns',
          'channel_email',
          'reports',
        ],
      },
    });

    expect(wrapper.vm.channels).toEqual(['channel_whatsapp', 'channel_email']);
    expect(wrapper.vm.functions).toEqual(['campaigns', 'reports']);
    expect(wrapper.vm.featureLabel('channel_whatsapp')).toBe('whatsapp');
    expect(wrapper.vm.form.active).toBe(true);
  });
});

describe('SummaryTab', () => {
  const SUMMARY = {
    kpis: {
      paid: 4,
      demo: 2,
      expiring: { 7: 1, 14: 2, 30: 3, 60: 5 },
      expired: 1,
      without_license: 9,
      suspended: 0,
      conversion: { demo_accounts: 4, converted: 1, rate: 25 },
    },
    expirations: [{ week_start: '2026-10-19', count: 1 }],
    by_plan: [{ name: 'Demo', count: 2 }],
  };

  beforeEach(() => {
    LicensesAPI.getSummary.mockReset();
    LicensesAPI.getSummary.mockResolvedValue({ data: SUMMARY });
  });

  const montarResumen = () =>
    shallowMount(SummaryTab, {
      mocks,
      stubs: [...stubs, 'BarChart', 'ReportMetricCard'],
    });

  it('arma las tarjetas y «por vencer» sigue a la ventana elegida', async () => {
    const wrapper = montarResumen();
    await esperar();

    const valor = clave => wrapper.vm.cards.find(c => c.key === clave).value;
    expect(valor('PAID')).toBe(4);
    expect(valor('EXPIRING')).toBe(1);
    expect(valor('CONVERSION')).toBe('25%');

    wrapper.vm.dias = 30;
    expect(valor('EXPIRING')).toBe(3);
  });

  it('una tarjeta abre Cuentas con su filtro; conversión no', async () => {
    const wrapper = montarResumen();
    await esperar();
    wrapper.vm.dias = 14;

    wrapper.vm.open(wrapper.vm.cards.find(c => c.key === 'EXPIRING'));
    wrapper.vm.open(wrapper.vm.cards.find(c => c.key === 'CONVERSION'));

    expect(wrapper.emitted('filter')).toEqual([
      [{ estado: 'por_vencer', dias: 14 }],
    ]);
  });

  it('las barras usan un solo color del tema', async () => {
    const wrapper = montarResumen();
    await esperar();

    const { datasets } = wrapper.vm.expirationsChart;
    expect(datasets).toHaveLength(1);
    expect(datasets[0].backgroundColor).toMatch(/^rgb\(/);
  });
});
