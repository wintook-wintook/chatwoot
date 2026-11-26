import axios from 'axios';
import store from '../../googleCalendar';

// feat/ventana_evento_calendario F5 (D7) — eliminar en el calendario de un compañero.
const { actions } = store;
global.axios = axios;
vi.mock('axios');

const rows = [
  {
    agent_id: 4,
    events: [
      { id: 'e1' },
      { id: 's_1', recurring_event_id: 's' },
      { id: 's_2', recurring_event_id: 's' },
    ],
  },
  { agent_id: 9, events: [{ id: 'e1' }] },
];

const run = (action, payload) => {
  const commit = vi.fn();
  const ctx = { commit, state: { coworkerEvents: rows } };
  ctx.dispatch = (name, p) => actions[name](ctx, p);
  return { commit, done: actions[action](ctx, payload) };
};

describe('googleCalendar · eventos de compañeros (F5)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('quita el evento solo de ese compañero; con serie, todas sus fechas', () => {
    let { commit } = run('removeCoworkerEvent', { agentId: 4, eventId: 'e1' });
    expect(commit.mock.calls[0][1][0].events.map(e => e.id)).toEqual([
      's_1',
      's_2',
    ]);
    expect(commit.mock.calls[0][1][1].events).toHaveLength(1);

    ({ commit } = run('removeCoworkerEvent', {
      agentId: 4,
      eventId: 's_1',
      seriesId: 's',
    }));
    expect(commit.mock.calls[0][1][0].events.map(e => e.id)).toEqual(['e1']);
  });

  it('elimina con agent_id, alcance y aviso', async () => {
    axios.delete.mockResolvedValue({ data: { deleted: true } });
    const { done } = run('deleteCoworkerEvent', {
      agentId: 4,
      eventId: 's_1',
      scope: 'one',
      notify: true,
      seriesId: 's',
    });
    await done;
    const [url, config] = axios.delete.mock.calls[0];
    expect(url).toMatch(/\/google_calendar\/events\/s_1$/);
    expect(config.params).toEqual({ agent_id: 4, scope: 'one', notify: true });
  });

  it('si Google lo rechaza, el evento regresa', async () => {
    axios.delete.mockRejectedValue({ response: { status: 403 } });
    const { commit, done } = run('deleteCoworkerEvent', {
      agentId: 4,
      eventId: 'e1',
    });
    await expect(done).rejects.toEqual({ response: { status: 403 } });
    expect(commit).toHaveBeenLastCalledWith('SET_COWORKER_EVENTS', rows);
  });
});
