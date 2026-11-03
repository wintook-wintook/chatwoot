/* global axios */
// Plan-Agenda — las tareas agendadas del calendario: con caso o solo con su contacto.
import ApiClient from './ApiClient';

class AgendaItemsAPI extends ApiClient {
  constructor() {
    super('agenda_items', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  // Casos abiertos para ligar: { contact_id, organization_id }
  cases(params = {}) {
    return axios.get(`${this.url}/cases`, { params });
  }

  updateItem(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }
}

export default new AgendaItemsAPI();
