// Academia Kontrolya — «Mi capacitación»: pinta los módulos y manda «Revisar» al servidor.
import { shallowMount } from '@vue/test-utils';
import AcademyIndex from '../AcademyIndex.vue';
import AcademyAPI from 'dashboard/api/academy';

vi.mock('dashboard/api/academy', () => ({
  default: {
    get: vi.fn(),
    start: vi.fn(() => Promise.resolve({ data: {} })),
    check: vi.fn(),
    confirm: vi.fn(() => Promise.resolve({ data: {} })),
    guide: vi.fn(),
    createPractice: vi.fn(() => Promise.resolve({ data: {} })),
    deletePractice: vi.fn(),
  },
}));

const flushPromises = () =>
  new Promise(r => {
    setTimeout(r);
  });

const board = {
  done: 1,
  total: 3,
  practice: { contact_id: null },
  modules: [
    {
      key: 'conversaciones',
      title: 'Conversaciones',
      summary: 'Contestar',
      status: 'in_progress',
      done: 1,
      total: 2,
      steps: [
        {
          key: 'leer',
          kind: 'lesson',
          title: 'Cómo se atiende',
          guide: 'conversaciones',
          status: 'done',
        },
        {
          key: 'responder',
          kind: 'exercise',
          title: 'Contesta a un cliente',
          path: 'dashboard',
          status: 'pending',
        },
      ],
    },
    {
      key: 'contactos',
      title: 'Contactos',
      summary: 'Alta',
      status: 'pending',
      done: 0,
      total: 1,
      steps: [
        {
          key: 'practica',
          kind: 'exercise',
          title: 'Crea tu Cliente de práctica',
          status: 'pending',
        },
      ],
    },
  ],
};

const setupBoard = {
  done: 1,
  total: 2,
  practice: {},
  modules: [
    {
      key: 'cuenta',
      title: 'Configura tu cuenta',
      summary: 'Lo básico',
      status: 'in_progress',
      done: 1,
      total: 2,
      steps: [
        {
          key: 'etapas',
          kind: 'setup',
          level: 'required',
          title: 'Revisa tus etapas',
          path: 'tickets/types',
          confirm: 'Así me sirven',
          status: 'pending',
        },
        {
          key: 'motivos',
          kind: 'setup',
          level: 'recommended',
          title: 'Motivos',
          path: 'tickets/close-reasons',
          confirm: 'Así me sirven',
          confirmed_by: 'Ana',
          status: 'done',
        },
      ],
    },
  ],
};

const mount = async (data = board) => {
  AcademyAPI.get.mockResolvedValue({ data });
  const wrapper = shallowMount(AcademyIndex, {
    mocks: {
      $t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
      $route: { params: { accountId: 1 } },
      $router: { push: vi.fn() },
      $emitter: { emit: vi.fn() },
    },
    stubs: {
      WootButton: {
        template: '<button @click="$emit(\'click\')"><slot /></button>',
      },
      FluentIcon: true,
      WootModal: true,
      WootConfirmModal: true,
    },
  });
  await flushPromises();
  return wrapper;
};

describe('AcademyIndex', () => {
  beforeEach(() => vi.clearAllMocks());

  it('abre el módulo que sigue y muestra sus pasos', async () => {
    const wrapper = await mount();
    expect(wrapper.text()).toContain('ACADEMY.TITLE');
    expect(wrapper.text()).toContain('Contesta a un cliente');
    expect(wrapper.text()).not.toContain('Crea tu Cliente de práctica');
  });

  it('«Revisar» le pregunta al servidor y muestra lo que contestó', async () => {
    AcademyAPI.check.mockResolvedValue({
      data: { found: false, message: 'Todavía no veo una respuesta tuya' },
    });
    const wrapper = await mount();
    const button = wrapper
      .findAll('button')
      .wrappers.find(b => b.text() === 'ACADEMY.CHECK');
    await button.trigger('click');
    await flushPromises();
    expect(AcademyAPI.check).toHaveBeenCalledWith(
      'conversaciones',
      'responder'
    );
    expect(wrapper.text()).toContain('Todavía no veo una respuesta tuya');
  });

  it('«Hazlo» empieza a contar y lleva a la pantalla', async () => {
    const wrapper = await mount();
    const button = wrapper
      .findAll('button')
      .wrappers.find(b => b.text() === 'ACADEMY.DO_IT');
    await button.trigger('click');
    await flushPromises();
    expect(AcademyAPI.start).toHaveBeenCalledWith(
      'conversaciones',
      'responder'
    );
    expect(wrapper.vm.$router.push).toHaveBeenCalledWith(
      '/app/accounts/1/dashboard'
    );
  });

  it('configuración: «Así me sirve» lo acepta y lo aceptado se puede deshacer', async () => {
    const wrapper = await mount(setupBoard);
    expect(wrapper.text()).toContain('ACADEMY.LEVEL.required');
    expect(wrapper.text()).not.toContain('ACADEMY.PRACTICE.TITLE');
    const buttons = wrapper.findAll('button').wrappers;
    await buttons.find(b => b.text() === 'Así me sirven').trigger('click');
    await flushPromises();
    expect(AcademyAPI.confirm).toHaveBeenCalledWith('cuenta', 'etapas', false);

    await buttons.find(b => b.text() === 'ACADEMY.UNDO').trigger('click');
    await flushPromises();
    expect(AcademyAPI.confirm).toHaveBeenCalledWith('cuenta', 'motivos', true);
  });
});
