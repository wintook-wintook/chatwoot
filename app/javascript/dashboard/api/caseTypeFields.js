// ================================================================================
// @tickets_cases 2K
// ================================================================================
// API Client: CaseTypeFieldsAPI
// Campos personalizados anidados bajo un tipo de caso.
// ================================================================================

import ApiClient from './ApiClient';

/* global axios */

class CaseTypeFieldsAPI extends ApiClient {
  constructor() {
    super('case_types', { accountScoped: true });
  }

  fieldsUrl(caseTypeId) {
    return `${this.url}/${caseTypeId}/fields`;
  }

  getAll(caseTypeId) {
    return axios.get(this.fieldsUrl(caseTypeId));
  }

  createField(caseTypeId, params) {
    return axios.post(this.fieldsUrl(caseTypeId), { case_type_field: params });
  }

  updateField(caseTypeId, fieldId, params) {
    return axios.patch(`${this.fieldsUrl(caseTypeId)}/${fieldId}`, {
      case_type_field: params,
    });
  }

  deleteField(caseTypeId, fieldId) {
    return axios.delete(`${this.fieldsUrl(caseTypeId)}/${fieldId}`);
  }
}

export default new CaseTypeFieldsAPI();
