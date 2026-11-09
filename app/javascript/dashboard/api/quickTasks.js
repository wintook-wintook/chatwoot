/* global axios */
// Plan-Agenda — tareas de captura rápida, sin caso. Las `create/update/delete` de ApiClient.
import ApiClient from './ApiClient';

class QuickTasksAPI extends ApiClient {
  constructor() {
    super('quick_tasks', { accountScoped: true });
  }

  // Cancelar con motivo: { reason_id, comment, minutes }.
  cancel(id, reason) {
    return axios.post(`${this.url}/${id}/cancel`, reason);
  }
}

export default new QuickTasksAPI();
