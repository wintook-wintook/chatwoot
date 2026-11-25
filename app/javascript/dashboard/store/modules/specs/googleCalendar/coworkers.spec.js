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

  it('fetchCoworkers guarda el estado de cada compañero', async () => {
    const commit = vi.fn();
    const coworkers = [{ agent_id: 4, access: 'details', can_schedule: true }];
    axios.get.mockResolvedValue({ data: { coworkers } });
    await actions.fetchCoworkers({ commit });
    expect(commit).toHaveBeenCalledWith('SET_COWORKERS', { coworkers });
  });

  it('fetchCoworkers distingue «reconectar» de «sin Google»', async () => {
    const commit = vi.fn();
    axios.get.mockRejectedValue({ response: { data: { error: 'reconnect' } } });
    await actions.fetchCoworkers({ commit });
    expect(commit).toHaveBeenCalledWith('SET_COWORKERS', {
      coworkers: [],
      error: 'reconnect',
    });

    axios.get.mockRejectedValue({ response: { data: { error: 'x' } } });
    await actions.fetchCoworkers({ commit });
    expect(commit).toHaveBeenLastCalledWith('SET_COWORKERS', {
      coworkers: [],
      error: 'not_connected',
    });
  });

  it('fetchCoworkerEvents no consulta nada si no hay palomeados', async () => {
    const commit = vi.fn();
    await actions.fetchCoworkerEvents(
      { commit, state: { selectedCoworkerIds: [] } },
      {}
    );
    expect(axios.get).not.toHaveBeenCalled();
    expect(commit).toHaveBeenCalledWith('SET_COWORKER_EVENTS', []);
  });

  it('fetchCoworkerEvents pide solo los palomeados con el rango visible', async () => {
    const commit = vi.fn();
    const rows = [{ agent_id: 4, access: 'free_busy', events: [] }];
    axios.get.mockResolvedValue({ data: { coworkers: rows } });
    const range = { start: '2026-11-23', end: '2026-11-30' };
    await actions.fetchCoworkerEvents(
      { commit, state: { selectedCoworkerIds: [4] } },
      range
    );
    expect(axios.get).toHaveBeenCalledWith(
      expect.stringContaining('/google_calendar/coworkers/events'),
      { params: { agent_ids: [4], ...range } }
    );
    expect(commit).toHaveBeenCalledWith('SET_COWORKER_EVENTS', rows);
  });

  it('toggleCoworker palomea / despalomea y vuelve a pedir eventos', () => {
    const commit = vi.fn();
    const dispatch = vi.fn();
    actions.toggleCoworker(
      { commit, dispatch, state: { selectedCoworkerIds: [4] } },
      { agentId: 5, range: {} }
    );
    expect(commit).toHaveBeenCalledWith('SET_SELECTED_COWORKERS', [4, 5]);
    actions.toggleCoworker(
      { commit, dispatch, state: { selectedCoworkerIds: [4, 5] } },
      { agentId: 4, range: {} }
    );
    expect(commit).toHaveBeenLastCalledWith('SET_SELECTED_COWORKERS', [5]);
    expect(dispatch).toHaveBeenCalledWith('fetchCoworkerEvents', {});
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
