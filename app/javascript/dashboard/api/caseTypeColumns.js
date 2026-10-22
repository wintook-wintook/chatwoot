// ================================================================================
// @tickets_cases — Columnas del Kanban por Tipo de Caso (Opción A+)
// ================================================================================
// API Client: CaseTypeColumnsAPI
// Columnas del tablero anidadas bajo un tipo de caso.
// ================================================================================

import ApiClient from './ApiClient';

/* global axios */

class CaseTypeColumnsAPI extends ApiClient {
  constructor() {
    super('case_types', { accountScoped: true });
  }

  columnsUrl(caseTypeId) {
    return `${this.url}/${caseTypeId}/columns`;
  }

  getAll(caseTypeId) {
    return axios.get(this.columnsUrl(caseTypeId));
  }

  createColumn(caseTypeId, params) {
    return axios.post(this.columnsUrl(caseTypeId), {
      case_type_column: params,
    });
  }

  updateColumn(caseTypeId, columnId, params) {
    return axios.patch(`${this.columnsUrl(caseTypeId)}/${columnId}`, {
      case_type_column: params,
    });
  }

  deleteColumn(caseTypeId, columnId) {
    return axios.delete(`${this.columnsUrl(caseTypeId)}/${columnId}`);
  }

  // Plan-Plantilla-Tareas-Etapa — tareas plantilla de una etapa.
  tasksUrl(caseTypeId, columnId) {
    return `${this.columnsUrl(caseTypeId)}/${columnId}/tasks`;
  }

  getTasks(caseTypeId, columnId) {
    return axios.get(this.tasksUrl(caseTypeId, columnId));
  }

  createTask(caseTypeId, columnId, task) {
    return axios.post(this.tasksUrl(caseTypeId, columnId), { task });
  }

  updateTask(caseTypeId, columnId, taskId, task) {
    return axios.patch(`${this.tasksUrl(caseTypeId, columnId)}/${taskId}`, {
      task,
    });
  }

  deleteTask(caseTypeId, columnId, taskId) {
    return axios.delete(`${this.tasksUrl(caseTypeId, columnId)}/${taskId}`);
  }

  reorderTasks(caseTypeId, columnId, ids) {
    return axios.put(`${this.tasksUrl(caseTypeId, columnId)}/reorder`, {
      ids,
    });
  }

  // Guarda el set completo de columnas del tipo en una transacción.
  replaceColumns(caseTypeId, columns) {
    return axios.put(`${this.columnsUrl(caseTypeId)}/replace`, { columns });
  }
}

export default new CaseTypeColumnsAPI();
