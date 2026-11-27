/* global axios */
// Historial de una tarea (con o sin caso): { task, items } — Cases::TaskHistory.
import ApiClient from './ApiClient';

class TaskHistoryAPI extends ApiClient {
  constructor() {
    super('case_tasks', { accountScoped: true });
  }

  get(taskId) {
    return axios.get(`${this.url}/${taskId}/history`);
  }
}

export default new TaskHistoryAPI();
