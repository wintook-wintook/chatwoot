// Catálogos › Resultados de tareas: get/create/update/delete de ApiClient.
/* global axios */
import ApiClient from './ApiClient';

class TaskOutcomesAPI extends ApiClient {
  constructor() {
    super('task_outcomes', { accountScoped: true });
  }

  // Exigir el tiempo dedicado en los reportes (Ajustes).
  updateSettings({ requireMinutes }) {
    return axios.patch(`${this.url}/settings`, {
      require_minutes: requireMinutes,
    });
  }
}

export default new TaskOutcomesAPI();
