import { shallowMount } from '@vue/test-utils';
import ContactAPI from 'dashboard/api/contacts';
import AgendaItemsAPI from 'dashboard/api/agendaItems';
import PeoplePicker, { isEmail, splitEmails } from '../PeoplePicker.vue';

// feat/ventana_evento_calendario F2 — un solo buscador de participantes.
vi.mock('dashboard/api/contacts', () => ({ default: { search: vi.fn() } }));
vi.mock('dashboard/api/agendaItems', () => ({ default: { busy: vi.fn() } }));

const agents = [
  { id: 1, name: 'Admin', email: 'admin@x.com' },
  { id: 4, name: 'Andres Liverio', email: 'andres@x.com' },
  { id: 5, name: 'Mario Duarte', email: 'mario@x.com' },
];

const mountPicker = (props = {}) =>
  shallowMount(PeoplePicker, {
    propsData: { organizerId: 1, allowAgents: true, ...props },
    mocks: {
      $t: (key, vars) =>
        vars ? `${key}:${Object.values(vars).join('|')}` : key,
      $store: { getters: { 'agents/getAgents': agents }, dispatch: vi.fn() },
    },
    stubs: {
      'woot-button': {
        template: '<button @click="$emit(\'click\')"><slot /></button>',
      },
      'fluent-icon': true,
    },
  });

const type = async (wrapper, text) => {
  const input = wrapper.find('[data-test="people-search"]');
  await input.setValue(text);
  await input.trigger('focus');
};

describe('PeoplePicker', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    ContactAPI.search.mockResolvedValue({ data: { payload: [] } });
    AgendaItemsAPI.busy.mockResolvedValue({ data: { busy: [] } });
  });
  afterEach(() => vi.useRealTimers());

  it('reconoce correos y los separa por comas, punto y coma o renglones', () => {
    expect(isEmail('a@x.com')).toBe(true);
    expect(isEmail('a@x')).toBe(false);
    expect(splitEmails('a@x.com, b@y.com;c@z.com\nd@w.com')).toHaveLength(4);
  });

  it('varios correos con comas → todos invitados; lo que no es correo se queda en rojo', async () => {
    const wrapper = mountPicker({ attendees: ['a@x.com'] });
    await type(wrapper, 'a@x.com, b@y.com; juan');
    expect(wrapper.vm.flush()).toBe(false);
    expect(wrapper.emitted('update:attendees')[0]).toEqual([
      ['a@x.com', 'b@y.com'],
    ]);
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.query).toBe('juan');
    expect(wrapper.find('[data-test="people-invalid"]').text()).toContain(
      'juan'
    );
  });

  it('tarea agendada: el agente va como participante y el responsable no se ofrece', async () => {
    const wrapper = mountPicker();
    await type(wrapper, 'a');
    const titles = wrapper.vm.options.map(o => o.title);
    expect(titles).toContain('Andres Liverio');
    expect(titles).not.toContain('Admin');
    wrapper.vm.pick(wrapper.vm.options.find(o => o.title === 'Andres Liverio'));
    expect(wrapper.emitted('update:participantIds')[0]).toEqual([[4]]);
  });

  it('evento solo de Google: el agente va como invitado con su correo', async () => {
    const wrapper = mountPicker({ allowAgents: false });
    await type(wrapper, 'mario');
    wrapper.vm.pick(wrapper.vm.options[0]);
    expect(wrapper.emitted('update:attendees')[0]).toEqual([['mario@x.com']]);
  });

  it('busca contactos con correo y los invita con su nombre', async () => {
    ContactAPI.search.mockResolvedValue({
      data: {
        payload: [
          { id: 9, name: 'Juan Ruiz', email: 'juan@cliente.com' },
          { id: 10, name: 'Sin correo', email: '' },
        ],
      },
    });
    const wrapper = mountPicker();
    await type(wrapper, 'juan');
    vi.advanceTimersByTime(350);
    await Promise.resolve();
    await wrapper.vm.$nextTick();
    expect(ContactAPI.search).toHaveBeenCalledWith('juan');
    const contact = wrapper.vm.options.find(o => o.type === 'contact');
    expect(contact.title).toBe('Juan Ruiz');
    expect(wrapper.vm.options.some(o => o.title === 'Sin correo')).toBe(false);
    wrapper.vm.pick(contact);
    expect(wrapper.emitted('update:attendees')[0]).toEqual([
      ['juan@cliente.com'],
    ]);
    await wrapper.setProps({ attendees: ['juan@cliente.com'] });
    expect(wrapper.vm.rows[0]).toMatchObject({
      title: 'Juan Ruiz',
      sub: 'GOOGLE_CALENDAR.PEOPLE.GUEST · juan@cliente.com',
    });
  });

  it('un correo escrito completo se ofrece para invitar', async () => {
    const wrapper = mountPicker();
    await type(wrapper, 'jefe@empresa.com');
    expect(wrapper.vm.options.map(o => o.type)).toContain('email');
  });

  it('D4: sugiere al cliente y no lo agrega solo', async () => {
    const client = { name: 'Juan', email: 'juan@cliente.com' };
    const wrapper = mountPicker({ client });
    expect(wrapper.emitted('update:attendees')).toBeUndefined();
    await wrapper.find('[data-test="people-client"] button').trigger('click');
    expect(wrapper.emitted('update:attendees')[0]).toEqual([
      ['juan@cliente.com'],
    ]);
    await wrapper.setProps({ attendees: ['juan@cliente.com'] });
    expect(wrapper.find('[data-test="people-client"]').exists()).toBe(false);
  });

  it('cada persona en su fila con ✕ para quitarla', async () => {
    const wrapper = mountPicker({
      participantIds: [4],
      attendees: ['a@x.com'],
    });
    expect(wrapper.vm.rows.map(r => r.title)).toEqual([
      'Andres Liverio',
      'a@x.com',
    ]);
    await wrapper.find('[data-test="people-remove-p-4"]').trigger('click');
    expect(wrapper.emitted('update:participantIds')[0]).toEqual([[]]);
    await wrapper
      .find('[data-test="people-remove-g-a@x.com"]')
      .trigger('click');
    expect(wrapper.emitted('update:attendees')[0]).toEqual([[]]);
  });

  it('avisa si un agente ya tiene algo a esa hora', async () => {
    AgendaItemsAPI.busy.mockResolvedValue({
      data: {
        busy: [
          {
            user_id: 4,
            items: [
              {
                title: 'Visita',
                start: '2026-11-27T16:00:00Z',
                end: '2026-11-27T17:00:00Z',
              },
            ],
          },
        ],
      },
    });
    const wrapper = mountPicker({
      participantIds: [4],
      startsAt: '2026-11-27T10:00',
      endsAt: '2026-11-27T11:00',
    });
    await Promise.resolve();
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.rows[0].busy).toContain('Visita');
  });

  it('sin correos (tarea al editar): solo agentes', async () => {
    const wrapper = mountPicker({ allowEmails: false });
    await type(wrapper, 'jefe@empresa.com');
    expect(wrapper.vm.options.some(o => o.type === 'email')).toBe(false);
    expect(wrapper.find('[data-test="people-invalid"]').exists()).toBe(false);
  });

  it('con las pastillas de Agentes a la vista, el buscador de Invitados no ofrece agentes', async () => {
    const wrapper = mountPicker({ allowAgents: false, searchAgents: false });
    await type(wrapper, 'andr');
    expect(wrapper.vm.options.some(o => o.type === 'agent')).toBe(false);
    expect(wrapper.vm.label).toBe('GOOGLE_CALENDAR.PEOPLE.LABEL_GUESTS');
  });
});
