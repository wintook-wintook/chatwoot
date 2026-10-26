/* global axios */
// Plan-Trabajo-Campo R3 — despacho de órdenes en campo.
import ApiClient from './ApiClient';

class FieldDispatchAPI extends ApiClient {
  constructor() {
    super('field_dispatch', { accountScoped: true });
  }

  board(day) {
    return axios.get(this.url, { params: { day } });
  }

  // { order_id, user_id, meeting_id?, starts_at?, duration_minutes? }
  assign(payload) {
    return axios.post(`${this.url}/assign`, payload);
  }
}

export default new FieldDispatchAPI();
