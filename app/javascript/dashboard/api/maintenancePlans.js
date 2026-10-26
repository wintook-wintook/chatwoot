/* global axios */
// Plan-Trabajo-Campo R4 — mantenimientos recurrentes.
import ApiClient from './ApiClient';

class MaintenancePlansAPI extends ApiClient {
  constructor() {
    super('maintenance_plans', { accountScoped: true });
  }

  // { contact_id?, active: 'all'? }
  list(params = {}) {
    return axios.get(this.url, { params });
  }

  create(data) {
    return axios.post(this.url, { maintenance_plan: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { maintenance_plan: data });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  // Genera ya la orden de la siguiente fecha.
  generate(id) {
    return axios.post(`${this.url}/${id}/generate`);
  }
}

export default new MaintenancePlansAPI();
