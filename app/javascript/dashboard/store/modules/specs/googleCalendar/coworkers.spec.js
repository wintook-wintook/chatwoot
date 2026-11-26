import axios from 'axios';
import store from '../../googleCalendar';

// fix/calendario_google F3 — compañeros vistos con mi conexión de Google.
const { actions, mutations } = store;
global.axios = axios;
vi.mock('axios');

describe('googleCalendar · compañeros', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.localStorage.clear();
  });

  it('fetchCoworkers guarda el estado y, si cambia quién comparte, pide sus eventos', async () => {
    const commit = vi.fn();
    const dispatch = vi.fn();
    const s = { coworkers: [], coworkerRange: { start: 'a' } };
    commit.mockImplementation((type, payload) => {
      if (type === 'SET_COWORKERS') s.coworkers = payload.coworkers;
    });
    const coworkers = [{ agent_id: 4, access: 'details', can_schedule: true }];
    axios.get.mockResolvedValue({ data: { coworkers } });

    await actions.fetchCoworkers({ commit, dispatch, state: s });
    expect(commit).toHaveBeenCalledWith('SET_COWORKERS', { coworkers });
    expect(dispatch).toHaveBeenCalledWith('fetchCoworkerEvents', {
      start: 'a',
    });

    dispatch.mockClear();
    await actions.fetchCoworkers({ commit, dispatch, state: s });
    expect(dispatch).not.toHaveBeenCalled();
  });

  it('fetchCoworkers distingue «reconectar» de «sin Google»', async () => {
    const commit = vi.fn();
    const s = { coworkers: [], coworkerRange: {} };
    axios.get.mockRejectedValue({ response: { data: { error: 'reconnect' } } });
    await actions.fetchCoworkers({ commit, dispatch: vi.fn(), state: s });
    expect(commit).toHaveBeenCalledWith('SET_COWORKERS', {
      coworkers: [],
      error: 'reconnect',
    });

    axios.get.mockRejectedValue({ response: { data: { error: 'x' } } });
    await actions.fetchCoworkers({ commit, dispatch: vi.fn(), state: s });
    expect(commit).toHaveBeenLastCalledWith('SET_COWORKERS', {
      coworkers: [],
      error: 'not_connected',
    });
  });

  it('fetchCoworkerEvents no consulta nada si nadie me comparte', async () => {
    const commit = vi.fn();
    await actions.fetchCoworkerEvents(
      { commit, state: { coworkers: [{ agent_id: 4, access: 'none' }] } },
      {}
    );
    expect(axios.get).not.toHaveBeenCalled();
    expect(commit).toHaveBeenCalledWith('SET_COWORKER_EVENTS', []);
  });

  it('fetchCoworkerEvents pide a todos los que me comparten (palomeados o no)', async () => {
    const commit = vi.fn();
    const rows = [{ agent_id: 4, access: 'free_busy', events: [] }];
    axios.get.mockResolvedValue({ data: { coworkers: rows } });
    const range = { start: '2026-11-23', end: '2026-11-30' };
    const coworkers = [
      { agent_id: 9, access: 'details' },
      { agent_id: 4, access: 'free_busy' },
      { agent_id: 5, access: 'none' },
    ];
    await actions.fetchCoworkerEvents({ commit, state: { coworkers } }, range);
    expect(axios.get).toHaveBeenCalledWith(
      expect.stringContaining('/google_calendar/coworkers/events'),
      { params: { agent_ids: [4, 9], ...range } }
    );
    expect(commit).toHaveBeenCalledWith('SET_COWORKER_RANGE', range);
    expect(commit).toHaveBeenCalledWith('SET_COWORKER_EVENTS', rows);
  });

  it('toggleCoworker es instantáneo: no consulta si ya están cargados', () => {
    const commit = vi.fn();
    const dispatch = vi.fn();
    const state = {
      selectedCoworkerIds: [4],
      coworkerEvents: [{ agent_id: 5, events: [] }],
      coworkerRange: {},
    };
    actions.toggleCoworker({ commit, dispatch, state }, { agentId: 5 });
    expect(commit).toHaveBeenCalledWith('SET_SELECTED_COWORKERS', [4, 5]);
    expect(dispatch).not.toHaveBeenCalled();

    actions.toggleCoworker(
      { commit, dispatch, state: { ...state, selectedCoworkerIds: [4, 5] } },
      { agentId: 4 }
    );
    expect(commit).toHaveBeenLastCalledWith('SET_SELECTED_COWORKERS', [5]);
    expect(dispatch).not.toHaveBeenCalled();
  });

  it('toggleCoworker pide eventos si aún no llegaron', () => {
    const dispatch = vi.fn();
    const state = {
      selectedCoworkerIds: [],
      coworkerEvents: [],
      coworkerRange: { start: 'x' },
    };
    actions.toggleCoworker(
      { commit: vi.fn(), dispatch, state },
      { agentId: 7 }
    );
    expect(dispatch).toHaveBeenCalledWith('fetchCoworkerEvents', {
      start: 'x',
    });
  });

  it('los palomeados se recuerdan en el navegador', () => {
    const s = { selectedCoworkerIds: [] };
    mutations.SET_SELECTED_COWORKERS(s, [4, 24422]);
    expect(s.selectedCoworkerIds).toEqual([4, 24422]);
    expect(
      JSON.parse(window.localStorage.getItem('gcal_selected_coworkers'))
    ).toEqual([4, 24422]);
  });
});
