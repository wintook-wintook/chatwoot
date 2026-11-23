/* global axios */
// Tareas que se repiten: una tarea fija que Kontrolya vuelve a crear cada cierto tiempo.
import ApiClient from './ApiClient';

class TaskRecurrencesAPI extends ApiClient {
  constructor() {
    super('task_recurrences', { accountScoped: true });
  }

  // { scope: 'mine' | 'all' }
  list(params = {}) {
    return axios.get(this.url, { params });
  }

  updateRecurrence(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  // La termina; las tareas que ya creó se quedan.
  end(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new TaskRecurrencesAPI();
