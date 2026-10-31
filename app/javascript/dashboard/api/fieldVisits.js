/* global axios */
// Plan-Trabajo-Campo R2 — portal del técnico.
import ApiClient from './ApiClient';

// El día se cuenta en la hora del usuario, no en la del servidor.
export const browserZone = () =>
  Intl.DateTimeFormat().resolvedOptions().timeZone;

class FieldVisitsAPI extends ApiClient {
  constructor() {
    super('field_visits', { accountScoped: true });
  }

  route(day) {
    return axios.get(this.url, { params: { day, tz: browserZone() } });
  }

  // «Mis trabajos»: sus órdenes terminadas entre from y to (YYYY-MM-DD).
  history(from, to) {
    return axios.get(`${this.url}/history`, { params: { from, to } });
  }

  onMyWay(id, etaMinutes) {
    return axios.post(`${this.url}/${id}/on_my_way`, {
      eta_minutes: etaMinutes,
    });
  }

  arrive(id, location = {}) {
    return axios.post(`${this.url}/${id}/arrive`, location);
  }

  finish(id, payload) {
    return axios.post(`${this.url}/${id}/finish`, payload);
  }

  sendToTechnician(id) {
    return axios.post(`${this.url}/${id}/send_to_technician`);
  }
}

export default new FieldVisitsAPI();
