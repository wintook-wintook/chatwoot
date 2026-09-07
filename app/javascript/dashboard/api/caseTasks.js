/* global axios */
// @tickets_cases — Tareas/subtareas de un ticket
import ApiClient from './ApiClient';

class CaseTasksAPI extends ApiClient {
  constructor() {
    super('case_tickets', { accountScoped: true });
  }

  getAll(ticketId) {
    return axios.get(`${this.url}/${ticketId}/tasks`);
  }

  // @tickets_cases — Bandeja de tareas (F1): índice a nivel cuenta, no anidado.
  // filters: { assignee_id, status, due, case_type_id, q, page }
  getMine(filters = {}) {
    const base = this.url.replace(/case_tickets$/, 'case_tasks');
    return axios.get(base, { params: filters });
  }

  createTask(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/tasks`, { case_task: data });
  }

  // `flags` viaja FUERA de `case_task`: son acciones del momento (cancelar las
  // reuniones huérfanas, extender la serie), no atributos de la tarea.
  updateTask(ticketId, id, data, flags = {}) {
    return axios.patch(`${this.url}/${ticketId}/tasks/${id}`, {
      case_task: data,
      ...flags,
    });
  }

  deleteTask(ticketId, id) {
    return axios.delete(`${this.url}/${ticketId}/tasks/${id}`);
  }
}

export default new CaseTasksAPI();
