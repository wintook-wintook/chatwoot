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

  // fix/calendario_google — compañeros vistos con MI conexión (Google aplica lo compartido).
  getCoworkers() {
    return axios.get(`${this.url}/coworkers`);
  }

  getCoworkerEvents(agentIds, params = {}) {
    return axios.get(`${this.url}/coworkers/events`, {
      params: { agent_ids: agentIds, ...params },
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

  createCalendar({ summary, description, timeZone, backgroundColor }) {
    return axios.post(`${this.url}/calendars/create_calendar`, {
      summary,
      description,
      time_zone: timeZone,
      background_color: backgroundColor,
    });
  }

  updateCalendar({ calendarId, summary, description, timeZone, backgroundColor }) {
    return axios.post(`${this.url}/calendars/update_calendar`, {
      calendar_id: calendarId,
      summary,
      description,
      time_zone: timeZone,
      background_color: backgroundColor,
    });
  }

  shareAgenda(payload) {
    return axios.post(`${this.url}/sharing`, payload);
  }

  getAvailability(params = {}) {
    return axios.get(`${this.url}/availability`, { params });
  }
}

export default new GoogleCalendarAPI();
