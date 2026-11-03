import { shallowMount } from '@vue/test-utils';
import AccountsTab from './AccountsTab.vue';
import IssueForm from './IssueForm.vue';
import PlanForm from './PlanForm.vue';
import SummaryTab from './SummaryTab.vue';
import Index from './Index.vue';
import PlansTab from './PlansTab.vue';
import AccountDetail from './AccountDetail.vue';
import LicensesAPI from 'dashboard/api/licenses';

// feat/licencias (F2b)
vi.mock('dashboard/api/licenses', () => ({
  default: {
    getAccounts: vi.fn(),
    issue: vi.fn(),
    createPlan: vi.fn(),
    getSummary: vi.fn(),
    getPlans: vi.fn(),
    getAccount: vi.fn(),
    cancel: vi.fn(),
    addAgents: vi.fn(),
    updateFeatures: vi.fn(),
    getChanges: vi.fn(),
    updatePlan: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
// El entorno de pruebas no puede leer el encabezado nativo (su BackButton): va vacío.
vi.mock(
  'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue',
  () => ({ default: { name: 'BaseSettingsHeader', render: h => h('div') } })
);

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
        sort: 'created_at',
        dir: 'desc',
      })
    );
  });

  it('ordena por columna en el servidor: fechas de la más reciente, nombre de la A', async () => {
    const wrapper = shallowMount(AccountsTab, { mocks, stubs });
    await esperar();

    wrapper.vm.sortBy('name');
    expect(LicensesAPI.getAccounts).toHaveBeenLastCalledWith(
      expect.objectContaining({ sort: 'name', dir: 'asc', page: 1 })
    );
    wrapper.vm.sortBy('name');
    expect(LicensesAPI.getAccounts).toHaveBeenLastCalledWith(
      expect.objectContaining({ sort: 'name', dir: 'desc' })
    );
    wrapper.vm.sortBy('updated_at');
    expect(LicensesAPI.getAccounts).toHaveBeenLastCalledWith(
      expect.objectContaining({ sort: 'updated_at', dir: 'desc' })
    );
  });

  it('sin cambios después de crearse, no tiene última modificación', () => {
    const wrapper = shallowMount(AccountsTab, { mocks, stubs });
    const creada = '2026-11-01T10:00:00Z';

    expect(
      wrapper.vm.updatedDate({ created_at: creada, updated_at: creada })
    ).toBe('—');
    expect(
      wrapper.vm.updatedDate({
        created_at: creada,
        updated_at: '2026-11-02T10:00:00Z',
      })
    ).not.toBe('—');
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

// Asignar licencia es una página (antes un modal).
describe('IssueForm', () => {
  const montarAsignar = (license = null) => {
    LicensesAPI.getAccount.mockResolvedValue({
      data: { id: 9, name: 'Grúas', license },
    });
    const push = vi.fn();
    const wrapper = shallowMount(IssueForm, {
      mocks: { ...mocks, $router: { push } },
      stubs: [...stubs, 'woot-confirm-modal'],
      propsData: { licensedAccountId: 9, plans: [PLAN] },
    });
    return { wrapper, push };
  };

  beforeEach(() => {
    LicensesAPI.issue.mockReset();
    LicensesAPI.issue.mockResolvedValue({ data: {} });
    LicensesAPI.getAccount.mockReset();
  });

  it('al elegir el plan precarga sus valores, manda lo ajustado y regresa a la ficha', async () => {
    const { wrapper, push } = montarAsignar();
    await esperar();
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
    expect(push).toHaveBeenCalledWith({
      name: 'licenses_accounts_show',
      params: { licensedAccountId: 9 },
      query: { tab: 'licenses' },
    });
    expect(await wrapper.vm.confirmLeave()).toBe(true);
  });

  it('con licencia vigente propone dejarla en cola', async () => {
    const { wrapper } = montarAsignar({ id: 1 });
    await esperar();
    expect(wrapper.vm.form.start).toBe('queue');
  });

  it('pregunta antes de salir con algo capturado', async () => {
    const { wrapper } = montarAsignar();
    await esperar();
    expect(await wrapper.vm.confirmLeave()).toBe(true);

    const showConfirmation = vi.fn().mockResolvedValue(false);
    wrapper.vm.$refs.leaveDialog = { showConfirmation };
    wrapper.vm.form.notes = 'pago anual';

    expect(await wrapper.vm.confirmLeave()).toBe(false);
  });
});

// La captura de un plan es una página (antes un modal).
describe('PlanForm', () => {
  const montarForm = (plan = { id: null }) => {
    const push = vi.fn();
    const wrapper = shallowMount(PlanForm, {
      mocks: { ...mocks, $router: { push } },
      stubs: [...stubs, 'woot-confirm-modal'],
      propsData: {
        plan,
        availableFeatures: [
          'channel_whatsapp',
          'campaigns',
          'channel_email',
          'reports',
        ],
      },
    });
    return { wrapper, push };
  };

  it('separa canales de funciones', () => {
    const { wrapper } = montarForm();

    expect(wrapper.vm.channels).toEqual(['channel_whatsapp', 'channel_email']);
    expect(wrapper.vm.functions).toEqual(['campaigns', 'reports']);
    expect(wrapper.vm.featureLabel('channel_whatsapp')).toBe('whatsapp');
    expect(wrapper.vm.form.active).toBe(true);
  });

  it('un plan nuevo arranca con lo que el sistema enciende; uno guardado, con lo suyo', () => {
    const nuevo = shallowMount(PlanForm, {
      mocks: { ...mocks, $router: { push: vi.fn() } },
      stubs: [...stubs, 'woot-confirm-modal'],
      propsData: {
        plan: { id: null },
        availableFeatures: ['channel_whatsapp', 'campaigns'],
        defaultFeatures: ['channel_whatsapp'],
      },
    });
    expect(nuevo.vm.form.features).toEqual(['channel_whatsapp']);
    expect(nuevo.vm.hasUnsavedChanges).toBe(false);

    const guardado = shallowMount(PlanForm, {
      mocks: { ...mocks, $router: { push: vi.fn() } },
      stubs: [...stubs, 'woot-confirm-modal'],
      propsData: {
        plan: { ...PLAN, features: ['campaigns'] },
        defaultFeatures: ['channel_whatsapp'],
      },
    });
    expect(guardado.vm.form.features).toEqual(['campaigns']);
  });

  it('al guardar regresa a la tabla de planes', async () => {
    LicensesAPI.updatePlan.mockResolvedValue({ data: {} });
    const { wrapper, push } = montarForm(PLAN);
    wrapper.vm.form.default_max_agents = 12;

    await wrapper.vm.save();

    expect(LicensesAPI.updatePlan).toHaveBeenCalledWith(
      3,
      expect.objectContaining({ name: 'Profesional', default_max_agents: 12 })
    );
    expect(wrapper.emitted('saved')).toHaveLength(1);
    expect(push).toHaveBeenCalledWith({ name: 'licenses_plans' });
    expect(await wrapper.vm.confirmLeave()).toBe(true);
  });

  it('pregunta antes de salir con cambios sin guardar', async () => {
    const { wrapper } = montarForm(PLAN);
    expect(await wrapper.vm.confirmLeave()).toBe(true);

    const showConfirmation = vi.fn().mockResolvedValue(false);
    wrapper.vm.$refs.leaveDialog = { showConfirmation };
    wrapper.vm.form.name = 'Profesional plus';

    expect(await wrapper.vm.confirmLeave()).toBe(false);
    expect(showConfirmation).toHaveBeenCalled();
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

// Resumen, Cuentas y Planes son opciones del menú secundario: una ruta cada una.
describe('Index', () => {
  const montarPagina = (tab, query = {}) => {
    LicensesAPI.getPlans.mockResolvedValue({
      data: { plans: [PLAN], available_features: [] },
    });
    const push = vi.fn();
    const wrapper = shallowMount(Index, {
      mocks: {
        ...mocks,
        $route: { meta: { tab }, query, fullPath: `/x/${tab}` },
        $router: { push },
        $store: { getters: { getCurrentUser: { can_manage_licenses: true } } },
      },
    });
    return { wrapper, push };
  };

  it('muestra la sección de la ruta, sin pestañas', async () => {
    const { wrapper } = montarPagina('plans');
    await esperar();

    expect(wrapper.findComponent({ name: 'PlansTab' }).exists()).toBe(true);
    expect(wrapper.find('woot-tabs-stub').exists()).toBe(false);
  });

  it('Cuentas arranca con el filtro que viene en la dirección', async () => {
    const { wrapper } = montarPagina('accounts', {
      estado: 'por_vencer',
      dias: '14',
    });
    await esperar();

    const cuentas = wrapper.findComponent({ name: 'AccountsTab' });
    expect(cuentas.props()).toMatchObject({
      initialEstado: 'por_vencer',
      initialDias: 14,
    });
  });

  it('«Nuevo plan» lleva a la captura; un plan que no existe lo dice', async () => {
    const { wrapper, push } = montarPagina('plans');
    await esperar();
    wrapper.vm.openNew();
    expect(push).toHaveBeenCalledWith({ name: 'licenses_plans_new' });

    const editar = shallowMount(Index, {
      mocks: {
        ...mocks,
        $route: {
          name: 'licenses_plans_edit',
          meta: { tab: 'plan_form' },
          params: { planId: '99' },
          query: {},
          fullPath: '/x/99',
        },
        $router: { push },
        $store: { getters: { getCurrentUser: { can_manage_licenses: true } } },
      },
    });
    await esperar();
    expect(editar.findComponent({ name: 'PlanForm' }).exists()).toBe(false);
    expect(editar.text()).toContain('PLAN_FORM.NOT_FOUND');
  });

  it('una tarjeta del resumen lleva a Cuentas con su filtro', async () => {
    const { wrapper, push } = montarPagina('summary');
    await esperar();

    wrapper.vm.openAccounts({ estado: 'por_vencer', dias: 14 });

    expect(push).toHaveBeenCalledWith({
      name: 'licenses_accounts',
      query: { estado: 'por_vencer', dias: 14 },
    });
  });
});

describe('PlansTab', () => {
  const plan = (id, name, extra = {}) => ({
    ...PLAN,
    id,
    name,
    license_type: 'paid',
    accounts_count: 0,
    ...extra,
  });
  const plans = [
    plan(1, 'Profesional', { duration_days: 180, accounts_count: 4 }),
    plan(2, 'Demo', { license_type: 'demo', duration_days: 15 }),
    plan(3, 'Básico', { active: false, duration_days: 30, accounts_count: 9 }),
  ];
  const montarPlanes = () =>
    shallowMount(PlansTab, {
      propsData: { plans, canManage: true },
      mocks: { ...mocks, $router: { push: vi.fn() } },
      stubs,
    });
  const nombres = wrapper => wrapper.vm.filteredPlans.map(p => p.name);

  it('ordena por nombre y, con un clic, por la columna elegida', () => {
    const wrapper = montarPlanes();

    expect(nombres(wrapper)).toEqual(['Básico', 'Demo', 'Profesional']);
    wrapper.vm.sortBy('ACCOUNTS');
    expect(nombres(wrapper)).toEqual(['Demo', 'Profesional', 'Básico']);
    wrapper.vm.sortBy('ACCOUNTS');
    expect(nombres(wrapper)).toEqual(['Básico', 'Profesional', 'Demo']);
  });

  it('filtra por texto, tipo y activos; limpiar los quita', () => {
    const wrapper = montarPlanes();

    wrapper.vm.q = 'pro';
    expect(nombres(wrapper)).toEqual(['Profesional']);
    wrapper.vm.q = '';
    wrapper.vm.typeFilter = 'demo';
    expect(nombres(wrapper)).toEqual(['Demo']);
    wrapper.vm.typeFilter = '';
    wrapper.vm.statusFilter = 'inactive';
    expect(nombres(wrapper)).toEqual(['Básico']);

    wrapper.vm.clearFilters();
    expect(wrapper.vm.hasActiveFilters).toBe(false);
    expect(nombres(wrapper)).toHaveLength(3);
  });

  it('pagina según «por página» y editar lleva a la captura del plan', () => {
    const wrapper = montarPlanes();
    wrapper.vm.perPage = 2;

    expect(wrapper.vm.pagedPlans).toHaveLength(2);
    wrapper.vm.onPageChange(2);
    expect(wrapper.vm.pagedPlans.map(p => p.name)).toEqual(['Profesional']);

    wrapper.vm.edit(plans[0]);
    expect(wrapper.vm.$router.push).toHaveBeenCalledWith({
      name: 'licenses_plans_edit',
      params: { planId: 1 },
    });
  });
});

// F6.1 — la ficha de una cuenta
describe('AccountDetail', () => {
  const FICHA = {
    id: 568,
    name: 'Grúas del Norte',
    status: 'active',
    wintook_internal: false,
    agents_count: 8,
    scheduled_count: 1,
    license_state: 'paid',
    license: {
      id: 7,
      name: 'Profesional',
      max_agents: 10,
      days_left: 43,
      starts_at: '2026-11-01T00:00:00Z',
      expires_at: '2026-12-15T00:00:00Z',
    },
    created_at: '2026-01-10T10:00:00Z',
    updated_at: '2026-10-30T10:00:00Z',
    inboxes_count: 5,
    enabled_features: ['campaigns', 'channel_whatsapp'],
    plan_features: ['channel_whatsapp', 'macros'],
    agents: [
      {
        id: 1,
        name: 'Ana',
        email: 'a@x.mx',
        role: 'administrator',
        joined_at: '2026-01-10T10:00:00Z',
      },
    ],
    licenses: [
      {
        id: 9,
        name: 'Anual',
        status: 'scheduled',
        license_type: 'paid',
        max_agents: 10,
      },
      {
        id: 7,
        name: 'Profesional',
        status: 'active',
        license_type: 'paid',
        max_agents: 10,
      },
    ],
  };
  const montarFicha = (query = {}, canManage = true) => {
    const replace = vi.fn();
    const push = vi.fn();
    const wrapper = shallowMount(AccountDetail, {
      propsData: {
        licensedAccountId: 568,
        canManage,
        availableFeatures: [
          'channel_whatsapp',
          'channel_email',
          'campaigns',
          'macros',
        ],
      },
      mocks: { ...mocks, $route: { query }, $router: { replace, push } },
      stubs: [
        ...stubs,
        'woot-tabs',
        'woot-tabs-item',
        'woot-switch',
        'woot-confirm-modal',
      ],
    });
    return { wrapper, replace, push };
  };

  beforeEach(() => {
    LicensesAPI.getAccount.mockReset();
    LicensesAPI.getAccount.mockResolvedValue({ data: FICHA });
    LicensesAPI.cancel.mockReset();
  });

  it('pide la cuenta y arma las tarjetas: agentes contra el tope, fila, funciones y bandejas', async () => {
    const { wrapper } = montarFicha();
    await esperar();

    expect(LicensesAPI.getAccount).toHaveBeenCalledWith(568);
    const tarjetas = Object.fromEntries(
      wrapper.vm.cards.map(c => [c.key, [c.value, c.hint]])
    );
    expect(tarjetas.AGENTS[1]).toContain('"count":2');
    expect(tarjetas.LICENSE).toEqual([
      'Profesional',
      expect.stringContaining('QUEUED'),
    ]);
    expect(tarjetas.FEATURES[0]).toBe(2);
    expect(tarjetas.INBOXES[0]).toBe(5);
  });

  it('la pestaña viene en la dirección; cambiarla la escribe ahí', async () => {
    const { wrapper, replace } = montarFicha({ tab: 'licenses' });
    await esperar();
    expect(wrapper.vm.tab).toBe('licenses');
    expect(wrapper.findAll('tbody tr')).toHaveLength(2);

    wrapper.vm.selectTab(2);
    expect(replace).toHaveBeenCalledWith({ query: { tab: 'features' } });
    expect(montarFicha({ tab: 'otra' }).wrapper.vm.tab).toBe('summary');
  });

  it('cancela una programada y vuelve a pedir la cuenta', async () => {
    LicensesAPI.cancel.mockResolvedValue({});
    const { wrapper } = montarFicha({ tab: 'licenses' });
    await esperar();

    await wrapper.vm.cancel(FICHA.licenses[0]);

    expect(LicensesAPI.cancel).toHaveBeenCalledWith(9);
    expect(LicensesAPI.getAccount).toHaveBeenCalledTimes(2);
  });

  it('agregar agentes solo sube el tope de la vigente y vuelve a pedir la cuenta', async () => {
    LicensesAPI.addAgents.mockResolvedValue({ data: { max_agents: 12 } });
    const { wrapper } = montarFicha();
    await esperar();
    expect(wrapper.vm.canAddAgents).toBe(true);

    wrapper.vm.openAddAgents();
    wrapper.vm.agentsToAdd = 0;
    expect(wrapper.vm.newAgentsTotal).toBeNull();
    wrapper.vm.agentsToAdd = 2;
    wrapper.vm.addReason = ' pidió dos más ';
    expect(wrapper.vm.newAgentsTotal).toBe(12);

    await wrapper.vm.saveAgents();

    expect(LicensesAPI.addAgents).toHaveBeenCalledWith(7, {
      add: 2,
      reason: 'pidió dos más',
    });
    expect(wrapper.vm.addingAgents).toBe(false);
    expect(LicensesAPI.getAccount).toHaveBeenCalledTimes(2);
  });

  it('sin «Gestionar» o sin licencia vigente no se pueden agregar agentes', async () => {
    const { wrapper } = montarFicha({}, false);
    await esperar();
    expect(wrapper.vm.canAddAgents).toBe(false);

    LicensesAPI.getAccount.mockResolvedValue({
      data: { ...FICHA, license: null },
    });
    const sinLicencia = montarFicha().wrapper;
    await esperar();
    expect(sinLicencia.vm.canAddAgents).toBe(false);
  });

  describe('Funciones (F6.3)', () => {
    const fila = (wrapper, name) =>
      wrapper.vm.featureRows.find(row => row.name === name);

    it('compara con el plan: encendida fuera del plan y apagada que viene en él', async () => {
      const { wrapper } = montarFicha({ tab: 'features' });
      await esperar();

      expect(fila(wrapper, 'campaigns')).toMatchObject({
        on: true,
        outside: true,
      });
      expect(fila(wrapper, 'macros')).toMatchObject({
        on: false,
        missing: true,
      });
      expect(fila(wrapper, 'channel_whatsapp')).toMatchObject({
        on: true,
        outside: false,
      });
      expect(wrapper.vm.outsidePlanCount).toBe(1);
      wrapper.vm.featureFilter = 'outside';
      expect(wrapper.vm.visibleFeatures.map(r => r.name)).toEqual([
        'campaigns',
        'macros',
      ]);
    });

    it('junta los cambios; regresar uno a como estaba deja de contar', async () => {
      const { wrapper } = montarFicha({ tab: 'features' });
      await esperar();

      wrapper.vm.toggleFeature(fila(wrapper, 'macros'));
      wrapper.vm.toggleFeature(fila(wrapper, 'campaigns'));
      expect(wrapper.vm.pendingFeatures).toEqual({
        macros: true,
        campaigns: false,
      });
      wrapper.vm.toggleFeature(fila(wrapper, 'campaigns'));
      expect(wrapper.vm.pendingFeatures).toEqual({ macros: true });
      expect(LicensesAPI.updateFeatures).not.toHaveBeenCalled();
    });

    it('guarda todo junto y queda con lo que dice el servidor', async () => {
      LicensesAPI.updateFeatures.mockResolvedValue({
        data: { enabled_features: ['campaigns', 'channel_whatsapp', 'macros'] },
      });
      const { wrapper } = montarFicha({ tab: 'features' });
      await esperar();
      wrapper.vm.toggleFeature(fila(wrapper, 'macros'));

      await wrapper.vm.saveFeatures();

      expect(LicensesAPI.updateFeatures).toHaveBeenCalledWith(568, {
        macros: true,
      });
      expect(wrapper.vm.pendingCount).toBe(0);
      expect(fila(wrapper, 'macros').on).toBe(true);
    });

    it('pregunta antes de salir con cambios sin guardar; sin permiso no cambia nada', async () => {
      const { wrapper } = montarFicha({ tab: 'features' });
      await esperar();
      expect(await wrapper.vm.confirmLeave()).toBe(true);
      wrapper.vm.toggleFeature(fila(wrapper, 'macros'));
      wrapper.vm.$refs.leaveDialog = {
        showConfirmation: vi.fn().mockResolvedValue(false),
      };
      expect(await wrapper.vm.confirmLeave()).toBe(false);

      const lector = montarFicha({ tab: 'features' }, false).wrapper;
      await esperar();
      lector.vm.toggleFeature(fila(lector, 'macros'));
      expect(lector.vm.pendingCount).toBe(0);
    });
  });

  it('el registro: se pide al abrir la pestaña, filtra y carga más', async () => {
    const evento = (id, extra = {}) => ({
      id,
      at: '2026-11-02T14:32:00Z',
      user: 'Ana',
      kind: 'licenses',
      event: 'license_agents',
      params: { name: 'Pro', from: 5, to: 7 },
      ...extra,
    });
    LicensesAPI.getChanges.mockReset();
    LicensesAPI.getChanges
      .mockResolvedValueOnce({ data: { events: [evento(9)], next_before: 9 } })
      .mockResolvedValueOnce({
        data: { events: [evento(4, { user: null })], next_before: null },
      })
      .mockResolvedValue({ data: { events: [], next_before: null } });
    const { wrapper } = montarFicha({ tab: 'changes' });
    await esperar();

    expect(LicensesAPI.getChanges).toHaveBeenCalledWith(568, {
      kind: undefined,
      from: undefined,
      to: undefined,
      before: undefined,
    });
    await wrapper.vm.fetchChanges(false);
    expect(LicensesAPI.getChanges).toHaveBeenLastCalledWith(
      568,
      expect.objectContaining({ before: 9 })
    );
    expect(wrapper.vm.changes.map(e => e.id)).toEqual([9, 4]);
    expect(wrapper.vm.changesNext).toBeNull();
    await wrapper.vm.$nextTick();
    expect(wrapper.text()).toContain('CHANGES.SYSTEM');

    wrapper.vm.changesKind = 'agents';
    await esperar();
    expect(LicensesAPI.getChanges).toHaveBeenLastCalledWith(
      568,
      expect.objectContaining({ kind: 'agents', before: undefined })
    );
    expect(wrapper.vm.changes).toEqual([]);
  });

  it('una cuenta que no existe lo dice y ofrece regresar', async () => {
    LicensesAPI.getAccount.mockRejectedValue(new Error('404'));
    const { wrapper, push } = montarFicha();
    await esperar();

    expect(wrapper.text()).toContain('DETAIL.NOT_FOUND');
    wrapper.vm.goToList();
    expect(push).toHaveBeenCalledWith({ name: 'licenses_accounts' });
  });
});
