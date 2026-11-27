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

  // Tareas pendientes para «Reportar avance»: { case_ticket_id } o { contact_id, organization_id }.
  tasks(params = {}) {
    return axios.get(`${this.url}/tasks`, { params });
  }

  // Pasarla a tarea sin hora: { notify_client }.
  toTask(id, data = {}) {
    return axios.post(`${this.url}/${id}/to_task`, data);
  }

  // ¿Los participantes ya tienen algo a esa hora? { user_ids, start, end, exclude_id }
  busy(params = {}) {
    return axios.get(`${this.url}/busy`, { params });
  }

  // Participante: «No puedo ir» { note }.
  decline(id, data = {}) {
    return axios.post(`${this.url}/${id}/decline`, data);
  }

  updateItem(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }
}

export default new AgendaItemsAPI();
