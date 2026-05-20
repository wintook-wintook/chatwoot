import GoogleCalendarAPI from '../../api/googleCalendar';

const state = {
  events: [],
  calendars: [],
  enabledCalendarIds: [],
  availability: [],
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
  getCalendars: s => s.calendars,
  getEnabledCalendarIds: s => s.enabledCalendarIds,
  getCalendarAvailability: s => s.availability,
  isCalendarConnected: s => s.connected,
  getCalendarEmail: s => s.googleEmail,
  getCalendarUIFlags: s => s.uiFlags,
};

const mutations = {
  SET_CALENDAR_EVENTS(s, events) {
    s.events = events;
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

  updateEvent: async (_, { eventId, start_time, end_time, summary, description, attendees }) => {
    await GoogleCalendarAPI.updateEvent(eventId, { start_time, end_time, summary, description, attendees });
  },

  shareAgenda: async (_, payload) => {
    await GoogleCalendarAPI.shareAgenda(payload);
  },

  createEvent: async ({ commit, dispatch }, payload) => {
    commit('SET_CALENDAR_UI_FLAG', { isCreating: true });
    try {
      await GoogleCalendarAPI.createEvent(payload);
    } catch (error) {
      throw new Error(error);
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
