// Catálogos › Resultados de tareas: get/create/update/delete de ApiClient.
import ApiClient from './ApiClient';

class TaskOutcomesAPI extends ApiClient {
  constructor() {
    super('task_outcomes', { accountScoped: true });
  }
}

export default new TaskOutcomesAPI();
