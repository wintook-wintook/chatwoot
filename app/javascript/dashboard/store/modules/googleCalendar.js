import GoogleCalendarAPI from '../../api/googleCalendar';
import AgendaItemsAPI from '../../api/agendaItems';

// fix/calendario_google — compañeros palomeados, recordados por navegador (conveniencia:
// si el navegador no deja guardar, simplemente arranca sin ninguno).
const SELECTED_COWORKERS_KEY = 'gcal_selected_coworkers';
const readSelectedCoworkers = () => {
  try {
    const raw = window.localStorage.getItem(SELECTED_COWORKERS_KEY);
    const ids = raw ? JSON.parse(raw) : [];
    return Array.isArray(ids) ? ids.map(Number).filter(Boolean) : [];
  } catch {
    return [];
  }
};
// Compañeros que me comparten algo (solo ocupado o detalles): de ellos se piden eventos.
const visibleCoworkerIds = coworkers =>
  (coworkers || [])
    .filter(c => ['details', 'free_busy'].includes(c.access))
    .map(c => c.agent_id)
    .sort((a, b) => a - b);
const saveSelectedCoworkers = ids => {
  try {
    window.localStorage.setItem(SELECTED_COWORKERS_KEY, JSON.stringify(ids));
  } catch {
    // sin almacenamiento: no pasa nada
  }
};

const state = {
  events: [],
  agendaItems: [],
  calendars: [],
  enabledCalendarIds: [],
  availability: [],
  // Compañeros: estado por agente ({ agent_id, access, can_schedule, busy_now }),
  // eventos de los palomeados y error de la consulta ('reconnect' | 'not_connected' | null).
  coworkers: [],
  coworkerEvents: [],
  selectedCoworkerIds: readSelectedCoworkers(),
  coworkersError: null,
  coworkerRange: {},
  connected: false,
  googleEmail: null,
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isConnecting: false,
    isFetchingCalendars: false,
  },
};

const getters = {
  getCalendarEvents: s => s.events,
  getAgendaItems: s => s.agendaItems,
  getCalendars: s => s.calendars,
  getEnabledCalendarIds: s => s.enabledCalendarIds,
  getCalendarAvailability: s => s.availability,
  getCoworkers: s => s.coworkers,
  getCoworkerEvents: s => s.coworkerEvents,
  getSelectedCoworkerIds: s => s.selectedCoworkerIds,
  getCoworkersError: s => s.coworkersError,
  isCalendarConnected: s => s.connected,
  getCalendarEmail: s => s.googleEmail,
  getCalendarUIFlags: s => s.uiFlags,
};

const mutations = {
  SET_CALENDAR_EVENTS(s, events) {
    s.events = events;
  },
  SET_AGENDA_ITEMS(s, items) {
    s.agendaItems = items;
  },
  SET_CALENDARS(s, { calendars, enabledIds }) {
    s.enabledCalendarIds = enabledIds;
    const allEnabled = enabledIds.length === 0;
    s.calendars = calendars.map(c => ({
      ...c,
      enabled: allEnabled || enabledIds.includes(c.id),
    }));
  },
  TOGGLE_CALENDAR(s, calendarId) {
    s.calendars = s.calendars.map(c =>
      c.id === calendarId ? { ...c, enabled: !c.enabled } : c
    );
    s.enabledCalendarIds = s.calendars.filter(c => c.enabled).map(c => c.id);
  },
  SET_CALENDAR_AVAILABILITY(s, availability) {
    s.availability = availability;
  },
  SET_COWORKERS(s, { coworkers, error }) {
    s.coworkers = coworkers;
    s.coworkersError = error || null;
  },
  SET_COWORKER_EVENTS(s, rows) {
    s.coworkerEvents = rows;
  },
  SET_COWORKER_RANGE(s, range) {
    s.coworkerRange = range || {};
  },
  SET_SELECTED_COWORKERS(s, ids) {
    s.selectedCoworkerIds = ids;
    saveSelectedCoworkers(ids);
  },
  SET_CALENDAR_CONNECTED(s, { connected, googleEmail }) {
    s.connected = connected;
    s.googleEmail = googleEmail || null;
  },
  SET_CALENDAR_UI_FLAG(s, flags) {
    s.uiFlags = { ...s.uiFlags, ...flags };
  },
};

const actions = {
  fetchEvents: async ({ commit }, params = {}) => {
    commit('SET_CALENDAR_UI_FLAG', { isFetching: true });
    try {
      const { data } = await GoogleCalendarAPI.getEvents(params);
      commit('SET_CALENDAR_EVENTS', data.events || []);
      commit('SET_CALENDAR_CONNECTED', { connected: true, googleEmail: data.google_email });
    } catch (error) {
      const isNotConnected =
        error.response?.status === 422 &&
        error.response?.data?.error === 'Google Calendar not connected';
      if (isNotConnected) {
        commit('SET_CALENDAR_CONNECTED', { connected: false });
      }
    } finally {
      commit('SET_CALENDAR_UI_FLAG', { isFetching: false });
    }
  },

  // Plan-Agenda — mis tareas y tareas agendadas: no dependen de tener Google.
  fetchAgendaItems: async ({ commit }, params = {}) => {
    try {
      const { data } = await AgendaItemsAPI.list(params);
      commit('SET_AGENDA_ITEMS', data.agenda_items || []);
    } catch {
      // silently ignore — el calendario sigue mostrando lo de Google
    }
  },

  createAgendaItem: async ({ commit }, payload) => {
    commit('SET_CALENDAR_UI_FLAG', { isCreating: true });
    try {
      await AgendaItemsAPI.create(payload);
    } finally {
      commit('SET_CALENDAR_UI_FLAG', { isCreating: false });
    }
  },

  fetchCalendars: async ({ commit }) => {
    commit('SET_CALENDAR_UI_FLAG', { isFetchingCalendars: true });
    try {
      const { data } = await GoogleCalendarAPI.getCalendars();
      commit('SET_CALENDARS', {
        calendars: data.calendars || [],
        enabledIds: data.enabled_ids || [],
      });
    } catch {
      // silently ignore — user may not have calendars endpoint yet
    } finally {
      commit('SET_CALENDAR_UI_FLAG', { isFetchingCalendars: false });
    }
  },

  subscribeCalendar: async ({ commit }, calendarId) => {
    const { data } = await GoogleCalendarAPI.subscribeCalendar(calendarId);
    commit('SET_CALENDARS', {
      calendars: data.calendars || [],
      enabledIds: data.enabled_ids || [],
    });
  },

  createCalendar: async ({ commit }, payload) => {
    const { data } = await GoogleCalendarAPI.createCalendar(payload);
    commit('SET_CALENDARS', {
      calendars: data.calendars || [],
      enabledIds: data.enabled_ids || [],
    });
  },

  updateCalendar: async ({ commit }, payload) => {
    const { data } = await GoogleCalendarAPI.updateCalendar(payload);
    commit('SET_CALENDARS', {
      calendars: data.calendars || [],
      enabledIds: data.enabled_ids || [],
    });
  },

  toggleCalendar: async ({ commit, state: s, dispatch }, calendarId) => {
    commit('TOGGLE_CALENDAR', calendarId);
    try {
      await GoogleCalendarAPI.updateCalendars(s.enabledCalendarIds);
      dispatch('fetchEvents');
    } catch {
      commit('TOGGLE_CALENDAR', calendarId); // revert on error
    }
  },

  fetchAvailability: async ({ commit }, params = {}) => {
    try {
      const { data } = await GoogleCalendarAPI.getAvailability(params);
      commit('SET_CALENDAR_AVAILABILITY', data.availability || []);
    } catch {
      // silently ignore
    }
  },

  // Si cambia quién me comparte, se vuelven a pedir sus eventos (para palomear al instante).
  fetchCoworkers: async ({ commit, dispatch, state: s }) => {
    const before = visibleCoworkerIds(s.coworkers).join(',');
    try {
      const { data } = await GoogleCalendarAPI.getCoworkers();
      commit('SET_COWORKERS', { coworkers: data.coworkers || [] });
    } catch (error) {
      const reason = error?.response?.data?.error;
      commit('SET_COWORKERS', {
        coworkers: [],
        error: reason === 'reconnect' ? 'reconnect' : 'not_connected',
      });
    }
    if (visibleCoworkerIds(s.coworkers).join(',') !== before) {
      dispatch('fetchCoworkerEvents', s.coworkerRange);
    }
  },

  // Eventos de TODOS los que me comparten algo (no solo los palomeados): así palomear es
  // instantáneo y solo cambia lo que se ve. El rango es el visible del calendario.
  fetchCoworkerEvents: async ({ commit, state: s }, range = {}) => {
    commit('SET_COWORKER_RANGE', range);
    const ids = visibleCoworkerIds(s.coworkers);
    if (!ids.length) {
      commit('SET_COWORKER_EVENTS', []);
      return;
    }
    try {
      const { data } = await GoogleCalendarAPI.getCoworkerEvents(ids, range);
      commit('SET_COWORKER_EVENTS', data.coworkers || []);
    } catch {
      commit('SET_COWORKER_EVENTS', []);
    }
  },

  toggleCoworker: ({ commit, dispatch, state: s }, { agentId }) => {
    const ids = s.selectedCoworkerIds.includes(agentId)
      ? s.selectedCoworkerIds.filter(id => id !== agentId)
      : [...s.selectedCoworkerIds, agentId];
    commit('SET_SELECTED_COWORKERS', ids);
    // Ya cargados: no hace falta preguntar. Solo si aún no llegaron.
    const loaded = s.coworkerEvents.some(r => r.agent_id === agentId);
    if (!loaded && ids.includes(agentId)) {
      dispatch('fetchCoworkerEvents', s.coworkerRange);
    }
  },

  connectAccount: async ({ commit, dispatch }) => {
    commit('SET_CALENDAR_UI_FLAG', { isConnecting: true });
    try {
      const { data } = await GoogleCalendarAPI.getAuthUrl();
      if (!data.url) return;

      const popup = window.open(
        data.url,
        'google_calendar_auth',
        'width=520,height=680,left=300,top=80'
      );

      const poll = setInterval(() => {
        if (!popup || popup.closed) {
          clearInterval(poll);
          commit('SET_CALENDAR_UI_FLAG', { isConnecting: false });
          dispatch('fetchEvents');
          dispatch('fetchCalendars');
          dispatch('fetchAvailability');
          dispatch('fetchCoworkers');
        }
      }, 600);
    } catch {
      commit('SET_CALENDAR_UI_FLAG', { isConnecting: false });
    }
  },

  disconnectAccount: async ({ commit }) => {
    try {
      await GoogleCalendarAPI.disconnect();
      commit('SET_CALENDAR_CONNECTED', { connected: false });
      commit('SET_CALENDAR_EVENTS', []);
      commit('SET_CALENDARS', { calendars: [], enabledIds: [] });
    } catch (error) {
      throw new Error(error);
    }
  },

  updateEvent: async (_, { eventId, start_time, end_time, summary, description, attendees, calendar_id }) => {
    await GoogleCalendarAPI.updateEvent(eventId, { start_time, end_time, summary, description, attendees, calendar_id });
  },

  // fix/calendario_eliminar F3 — se quita de la pantalla al momento; si Google falla, regresa.
  deleteEvent: async (
    { commit, state: s },
    { eventId, calendar_id, scope, notify, seriesId }
  ) => {
    const before = s.events;
    const gone = e =>
      e.id === eventId ||
      (scope === 'all' && !!seriesId && e.recurringEventId === seriesId);
    commit(
      'SET_CALENDAR_EVENTS',
      before.filter(e => !gone(e))
    );
    try {
      await GoogleCalendarAPI.deleteEvent(eventId, {
        calendar_id,
        scope,
        notify,
      });
    } catch (error) {
      commit('SET_CALENDAR_EVENTS', before);
      throw error;
    }
  },

  shareAgenda: async (_, payload) => {
    await GoogleCalendarAPI.shareAgenda(payload);
  },

  createEvent: async ({ commit, dispatch }, payload) => {
    commit('SET_CALENDAR_UI_FLAG', { isCreating: true });
    try {
      await GoogleCalendarAPI.createEvent(payload);
    } finally {
      commit('SET_CALENDAR_UI_FLAG', { isCreating: false });
    }
    dispatch('fetchEvents');
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
