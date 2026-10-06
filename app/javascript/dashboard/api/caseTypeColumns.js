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

  // Guarda el set completo de columnas del tipo en una transacción.
  replaceColumns(caseTypeId, columns) {
    return axios.put(`${this.columnsUrl(caseTypeId)}/replace`, { columns });
  }
}

export default new CaseTypeColumnsAPI();
