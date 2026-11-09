// Catálogos › Resultados de tareas: get/create/update/delete de ApiClient.
/* global axios */
import ApiClient from './ApiClient';

class TaskOutcomesAPI extends ApiClient {
  constructor() {
    super('task_outcomes', { accountScoped: true });
  }

  // purpose: 'report' (resultados del reporte, por omisión) | 'cancel' (motivos de cancelación).
  list(purpose = 'report') {
    return axios.get(this.url, { params: { purpose } });
  }

  createFor(purpose, data) {
    return axios.post(this.url, { ...data, purpose });
  }

  // Exigir el tiempo dedicado en los reportes (Ajustes).
  updateSettings({ requireMinutes }) {
    return axios.patch(`${this.url}/settings`, {
      require_minutes: requireMinutes,
    });
  }
}

export default new TaskOutcomesAPI();
