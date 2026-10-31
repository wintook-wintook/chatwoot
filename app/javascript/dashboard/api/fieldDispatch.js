/* global axios */
// Plan-Trabajo-Campo R3 — despacho de órdenes en campo.
import ApiClient from './ApiClient';
import { browserZone } from './fieldVisits';

class FieldDispatchAPI extends ApiClient {
  constructor() {
    super('field_dispatch', { accountScoped: true });
  }

  board(day) {
    return axios.get(this.url, { params: { day, tz: browserZone() } });
  }

  // { order_id, user_id, meeting_id?, starts_at?, duration_minutes? }
  assign(payload) {
    return axios.post(`${this.url}/assign`, { ...payload, tz: browserZone() });
  }

  // Visita sin orden: { meeting_id, user_id, starts_at?, day }
  moveVisit(payload) {
    return axios.post(`${this.url}/move_visit`, {
      ...payload,
      tz: browserZone(),
    });
  }
}

export default new FieldDispatchAPI();
