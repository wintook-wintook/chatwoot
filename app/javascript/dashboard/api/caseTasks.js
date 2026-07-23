// @tickets_cases — Tareas/subtareas de un ticket
import ApiClient from './ApiClient';

class CaseTasksAPI extends ApiClient {
  constructor() {
    super('case_tickets', { accountScoped: true });
  }

  getAll(ticketId) {
    return axios.get(`${this.url}/${ticketId}/tasks`);
  }

  createTask(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/tasks`, { case_task: data });
  }

  updateTask(ticketId, id, data) {
    return axios.patch(`${this.url}/${ticketId}/tasks/${id}`, { case_task: data });
  }

  deleteTask(ticketId, id) {
    return axios.delete(`${this.url}/${ticketId}/tasks/${id}`);
  }
}

export default new CaseTasksAPI();
