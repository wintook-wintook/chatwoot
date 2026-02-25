// app/javascript/dashboard/api/kanban.js
// KANBAN0725
import ApiClient from './ApiClient';

class KanbanAPI extends ApiClient {
  constructor() {
    super('conversations/kanban', { accountScoped: true });
  }

  getFilteredConversations(filters) {
    return axios.get(`${this.url}/filter_by_both_kanban`, {
      params: filters,
    });
  }

  filterByKanbanType(filters) {
    return axios.get(`${this.url}/filter_by_kanban_type`, {
      params: filters,
    });
  }

  filterByKanbanProcess(filters) {
    return axios.get(`${this.url}/filter_by_kanban_process`, {
      params: filters,
    });
  }

  filterByBothKanban(filters) {
    return axios.get(`${this.url}/filter_by_both_kanban`, {
      params: filters,
    });
  }
}

export default new KanbanAPI();