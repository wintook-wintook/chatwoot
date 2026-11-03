// Plan-Agenda — tareas de captura rápida, sin caso. Las `create/update/delete` de ApiClient.
import ApiClient from './ApiClient';

class QuickTasksAPI extends ApiClient {
  constructor() {
    super('quick_tasks', { accountScoped: true });
  }
}

export default new QuickTasksAPI();
