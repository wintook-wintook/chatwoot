// Plan Actividad del caso — una sola lista con filtros; un clic lleva a su pestaña.
import { shallowMount } from '@vue/test-utils';
import CaseActivity from '../activity/CaseActivity.vue';
import CaseTicketsAPI from 'dashboard/api/caseTickets';

vi.mock('dashboard/api/caseTickets', () => ({
  default: { getActivity: vi.fn(), getConversations: vi.fn() },
}));

// @vue/test-utils 1.x no trae flushPromises: basta con dejar correr la cola.
const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve, 0);
  });

const conversation = { display_id: 5, primary: true, inbox_name: 'Chat' };
const ITEMS = [
  {
    kind: 'messages',
    id: '1-2026-11-01',
    at: '2026-11-01T18:00:00Z',
    day: '2026-11-01',
    incoming: 2,
    outgoing: 1,
    conversation,
    last: { incoming: true, sender: 'Mario', content: 'Hola' },
  },
  {
    kind: 'event',
    id: 3,
    at: '2026-11-01T17:00:00Z',
    event_type: 'task_completed',
    payload: { sequence: 1, title: 'Llamar' },
  },
  {
    kind: 'event',
    id: 2,
    at: '2026-11-01T16:00:00Z',
    event_type: 'internal_note',
    payload: { content: 'Le marqué' },
  },
  {
    kind: 'event',
    id: 1,
    at: '2026-10-30T10:00:00Z',
    event_type: 'status_changed',
    payload: { from: 'open', to: 'in_progress' },
  },
];

const mountActivity = async () => {
  CaseTicketsAPI.getActivity.mockResolvedValue({
    data: { items: ITEMS, summary: { overdue_tasks: 0 } },
  });
  CaseTicketsAPI.getConversations.mockResolvedValue({
    data: { conversations: [conversation], unlinked: [] },
  });
  const wrapper = shallowMount(CaseActivity, {
    propsData: { ticket: { id: 7, contact_id: 3 } },
    mocks: {
      $t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
      $te: () => false,
      $i18n: { locale: 'es' },
    },
    stubs: { FluentIcon: true, WootButton: true },
  });
  await flushPromises();
  return wrapper;
};

describe('CaseActivity', () => {
  it('cuenta cada filtro y filtra la lista', async () => {
    const wrapper = await mountActivity();
    expect(wrapper.vm.counts).toMatchObject({
      all: 4,
      client: 1,
      tasks: 1,
      notes: 1,
      changes: 1,
    });
    wrapper.vm.setFilter('tasks');
    expect(wrapper.vm.filtered.map(i => i.id)).toEqual([3]);
  });

  it('parte la lista por día', async () => {
    const wrapper = await mountActivity();
    expect(wrapper.vm.days.map(d => d.items.length)).toEqual([3, 1]);
  });

  it('resume los mensajes: recibidos, enviados y el último', async () => {
    const wrapper = await mountActivity();
    const [messages] = ITEMS;
    expect(wrapper.vm.title(messages)).toContain('RECEIVED');
    expect(wrapper.vm.title(messages)).toContain('SENT');
    expect(wrapper.vm.lastLine(messages)).toBe('Mario: Hola');
  });

  it('un clic en una tarea abre Tareas; en mensajes de la principal, Conversación', async () => {
    const wrapper = await mountActivity();
    wrapper.vm.openItem(ITEMS[1]);
    wrapper.vm.openItem(ITEMS[0]);
    expect(wrapper.emitted('openTab')).toEqual([['tasks'], ['detail']]);
    expect(wrapper.vm.clickable(ITEMS[3])).toBe(false);
  });
});
