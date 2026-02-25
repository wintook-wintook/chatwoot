// app/javascript/dashboard/api/kanbanTypeProcesses.js
// KANBAN0725
import ApiClient from './ApiClient';

class KanbanTypeProcessAPI extends ApiClient {
  constructor() {
    super('kanban_type_processes', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(kanbanTypeProcessObj) {
    return axios.post(this.url, {
      kanban_type_process: kanbanTypeProcessObj,
    });
  }

  update(id, kanbanTypeProcessObj) {
    return axios.patch(`${this.url}/${id}`, {
      kanban_type_process: kanbanTypeProcessObj,
    });
  }

  // delete(id) {
  //   return axios.delete(`${this.url}/${id}`);
  // }
  async delete(id) {
    try {
      const response = await axios.delete(`${this.url}/${id}`);
      return response.data;
    } catch (error) {
      if (error.response?.status === 422) {
        // console.error('❌ Error 422 - Unprocessable Entity:', error.response.data);
        throw new Error(`No se puede eliminar un tipo de oportunidad con conversaciones asociadas`);
      }
      // console.error('❌ Delete error:', error.message);
      throw error;
    }
  }

  // 🆕 NUEVO MÉTODO: Obtener información de Kanban de una conversación
  getConversationKanbanInfo(conversationId) {
    return axios.get(`${this.url}/conversation/${conversationId}/kanban_info`);
  }
}

export default new KanbanTypeProcessAPI();