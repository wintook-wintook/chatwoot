/* global axios */
// Reporte de cierre: se manda antes de concluir la tarea.
import ApiClient from './ApiClient';

class TaskReportsAPI extends ApiClient {
  constructor() {
    super('task_reports', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  // item = { type: 'task' | 'meeting', id }
  send(item, { content, outcomeId, files }) {
    const data = new FormData();
    data.append('item_type', item.type);
    data.append('item_id', item.id);
    data.append('content', content);
    if (outcomeId) data.append('task_outcome_id', outcomeId);
    files.forEach(file => data.append('evidence[]', file));
    return axios.post(this.url, data);
  }
}

export default new TaskReportsAPI();
