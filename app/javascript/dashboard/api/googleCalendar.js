import ApiClient from './ApiClient';

class GoogleCalendarAPI extends ApiClient {
  constructor() {
    super('google_calendar', { accountScoped: true });
  }

  getAuthUrl() {
    return axios.post(`${this.url}/authorization`);
  }

  disconnect() {
    return axios.delete(`${this.url}/authorization`);
  }

  getEvents(params = {}) {
    return axios.get(`${this.url}/events`, { params });
  }

  createEvent(payload) {
    return axios.post(`${this.url}/events`, payload);
  }

  updateEvent(eventId, payload) {
    return axios.patch(`${this.url}/events/${eventId}`, payload);
  }

  getAgentEvents(agentId, params = {}) {
    return axios.get(`${this.url}/events/agent_events`, {
      params: { agent_id: agentId, ...params },
    });
  }

  getCalendars() {
    return axios.get(`${this.url}/calendars`);
  }

  updateCalendars(enabledIds) {
    return axios.patch(`${this.url}/calendars`, { enabled_ids: enabledIds });
  }

  subscribeCalendar(calendarId) {
    return axios.post(`${this.url}/calendars/subscribe`, { calendar_id: calendarId });
  }

  shareAgenda(payload) {
    return axios.post(`${this.url}/sharing`, payload);
  }

  getAvailability(params = {}) {
    return axios.get(`${this.url}/availability`, { params });
  }
}

export default new GoogleCalendarAPI();
