/* global axios */
// ================================================================================
// proyecto@ai_agent_assistant - F4
// ================================================================================
// API Client: TrackingTemplateVersionsAPI
// Descripción: historial en sitio de un Agente IA — snapshots, diff y restauración,
//   más la detección y el archivado de las copias «… V2 / V3 / V4».
//   Anidado bajo tracking_templates/:id (account-scoped).
// ================================================================================

import ApiClient from './ApiClient';

class TrackingTemplateVersionsAPI extends ApiClient {
  constructor() {
    super('tracking_templates', { accountScoped: true });
  }

  baseFor(templateId) {
    return `${this.url}/${templateId}/versions`;
  }

  list(templateId) {
    return axios.get(this.baseFor(templateId));
  }

  // `compareWith` permite comparar contra cualquier versión, no solo la anterior.
  show(templateId, id, compareWith) {
    return axios.get(`${this.baseFor(templateId)}/${id}`, {
      params: { compare_with: compareWith || undefined },
    });
  }

  restore(templateId, id) {
    return axios.post(`${this.baseFor(templateId)}/${id}/restore`);
  }

  siblings(templateId) {
    return axios.get(`${this.url}/${templateId}/siblings`);
  }

  archive(templateId) {
    return axios.post(`${this.url}/${templateId}/archive`);
  }

  unarchive(templateId) {
    return axios.post(`${this.url}/${templateId}/unarchive`);
  }
}

export default new TrackingTemplateVersionsAPI();
