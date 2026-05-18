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

  getAvailability(params = {}) {
    return axios.get(`${this.url}/availability`, { params });
  }
}

export default new GoogleCalendarAPI();
