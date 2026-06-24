/* global axios */
// ================================================================================
// proyecto@ai_agent_attachments
// ================================================================================
// API Client: AiAgentAttachmentsAPI
// Descripción: adjuntos de un Agente IA, anidados bajo tracking_templates/:id/attachments
//   (account-scoped). El `name` (slug) es la clave de la directiva {{name}}.
// ================================================================================

import ApiClient from './ApiClient';

class AiAgentAttachmentsAPI extends ApiClient {
  constructor() {
    super('tracking_templates', { accountScoped: true });
  }

  baseFor(templateId) {
    return `${this.url}/${templateId}/attachments`;
  }

  list(templateId) {
    return axios.get(this.baseFor(templateId));
  }

  upload(templateId, { name, file }) {
    const formData = new FormData();
    formData.append('name', name);
    formData.append('file', file);
    return axios.post(this.baseFor(templateId), formData);
  }

  rename(templateId, id, name) {
    return axios.patch(`${this.baseFor(templateId)}/${id}`, { name });
  }

  remove(templateId, id) {
    return axios.delete(`${this.baseFor(templateId)}/${id}`);
  }
}

export default new AiAgentAttachmentsAPI();
