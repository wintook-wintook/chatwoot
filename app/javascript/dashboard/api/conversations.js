/* global axios */
import ApiClient from './ApiClient';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  // KANBAN0725
  updateKanbanProcess(conversationId, kanbanData) {
    console.log('🔄 API: updateKanbanProcess llamado');
    console.log('📊 API: Parámetros:', { conversationId, kanbanData });

   // return axios.patch(`${this.url}/${conversationId}/update_kanban_process`, kanbanData);
   return axios.patch(`${this.url}/${conversationId}/update_kanban_process`, {
      conversation: kanbanData
    });
  }

  // ✅ MÉTODO MEJORADO: Con validaciones completas
  updateKanbanProcessEnhanced(conversationId, kanbanData) {
    console.log('🔄 API: updateKanbanProcessEnhanced llamado');
    console.log('📊 API: Parámetros:', { conversationId, kanbanData });

    return axios.patch(`${this.url}/${conversationId}/update_kanban_process_enhanced`, kanbanData);
  }

  // ✅ MÉTODO ESPECÍFICO: Solo actualizar kanban_process_id
  updateKanbanProcessOnly(conversationId, kanbanProcessId) {
    console.log('🔄 API: updateKanbanProcessOnly llamado');
    console.log('📊 API: Parámetros:', { conversationId, kanbanProcessId });

    return axios.patch(`${this.url}/${conversationId}/update_kanban_process_only`, {
      kanban_process_id: kanbanProcessId
    });
  }
  // =========================================================

  getByKanbanFilter(params) {
    const queryParams = new URLSearchParams();
    
    if (params.kanban_type_process_id) {
      queryParams.append('kanban_type_process_id', params.kanban_type_process_id);
    }
    
    if (params.kanban_process_id) {
      queryParams.append('kanban_process_id', params.kanban_process_id);
    }
    
    if (params.page) {
      queryParams.append('page', params.page);
    }

    // Agregar otros parámetros de filtrado existentes
    Object.keys(params).forEach(key => {
      if (!['kanban_type_process_id', 'kanban_process_id', 'page'].includes(key) && params[key]) {
        queryParams.append(key, params[key]);
      }
    });

    // ✅ USA this.url QUE YA INCLUYE EL accountId
    return axios.get(`${this.url}?${queryParams.toString()}`);
  }

  // Método adicional para obtener estadísticas de Kanban
  getKanbanStats(kanbanTypeProcessId = null) {
    const queryParams = new URLSearchParams();
    
    if (kanbanTypeProcessId) {
      queryParams.append('kanban_type_process_id', kanbanTypeProcessId);
    }
    
    queryParams.append('stats_only', 'true');

    return axios.get(`${this.url}?${queryParams.toString()}`);
  }

  // Método para mover conversaciones en lote entre procesos
  // bulkUpdateKanban(conversationIds, kanbanData) {
  //   return axios.patch(`${this.url}/bulk_update_kanban`, {
  //     conversation_ids: conversationIds,
  //     kanban_data: kanbanData,
  //   });
  // }
  // ✅ MÉTODO MASIVO: Actualización bulk de campos kanban
  bulkUpdateKanban(conversationId, kanbanData) {
    console.log('🔄 API: bulkUpdateKanban llamado');
    console.log('📊 API: Parámetros:', { conversationId, kanbanData });

    return axios.patch(`${this.url}/${conversationId}/bulk_update_kanban`, kanbanData);
  }

  // ✅ MÉTODO DE CONVENIENCIA: Limpiar campos kanban
  clearKanbanFields(conversationId) {
    console.log('🔄 API: clearKanbanFields llamado');
    console.log('📊 API: Parámetros:', { conversationId });

    return axios.patch(`${this.url}/${conversationId}/update_kanban_process`, {
      kanban_type_process_id: null,
      kanban_process_id: null
    });
  }

  // ✅ MÉTODO DE CONVENIENCIA: Asignar tipo y proceso automático
  assignKanbanTypeWithDefaultProcess(conversationId, kanbanTypeProcessId) {
    console.log('🔄 API: assignKanbanTypeWithDefaultProcess llamado');
    console.log('📊 API: Parámetros:', { conversationId, kanbanTypeProcessId });

    // Este método asigna el tipo y deja que el backend determine el proceso por defecto
    return axios.patch(`${this.url}/${conversationId}/update_kanban_process_enhanced`, {
      kanban_type_process_id: kanbanTypeProcessId
      // kanban_process_id se determinará automáticamente en el backend
    });
  }
  // KANBAN0725
}

export default new ConversationApi();