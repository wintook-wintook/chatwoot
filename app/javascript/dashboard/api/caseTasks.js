/* global axios */
// @tickets_cases — Tareas/subtareas de un ticket
import ApiClient from './ApiClient';
import { browserZone } from './fieldVisits';

class CaseTasksAPI extends ApiClient {
  constructor() {
    super('case_tickets', { accountScoped: true });
  }

  getAll(ticketId) {
    return axios.get(`${this.url}/${ticketId}/tasks`);
  }

  // @tickets_cases — Bandeja de tareas (F1): índice a nivel cuenta, no anidado.
  // filters: { assignee_id, status, due, case_type_id, q, page, item_type }
  // item_type: '' (fusiona tareas + reuniones agendadas) | 'task' | 'meeting'
  getMine(filters = {}) {
    const base = this.url.replace(/case_tickets$/, 'case_tasks');
    return axios.get(base, { params: { tz: browserZone(), ...filters } });
  }

  // Plan-Bandeja-Prioridad F2 — orden propio de «Mi día» (reemplaza el plan del
  // día): day = fecha LOCAL 'YYYY-MM-DD', taskIds = ids en el orden elegido.
  saveMyDayPlan(day, taskIds) {
    const base = this.url.replace(/case_tickets$/, 'case_tasks');
    return axios.put(`${base}/my_day_plan`, { day, task_ids: taskIds });
  }

  // Plan-Bandeja-Prioridad F4 — «Plan de mi día» con IA (explica, no reordena).
  myDayAi(day, tz) {
    const base = this.url.replace(/case_tickets$/, 'case_tasks');
    return axios.post(`${base}/my_day_ai`, { day, tz });
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
