/* global axios */
// Seguimiento IA — el agente nuevo con herramientas («Delegar a agente» en el caso).
import ApiClient from './ApiClient';
import { browserZone } from './fieldVisits';

const targetParams = target =>
  target && typeof target === 'object' ? target : { conversation_id: target };

class AiFollowUpsAPI extends ApiClient {
  constructor() {
    super('ai_follow_ups', { accountScoped: true });
  }

  forCase(caseId) {
    return axios.get(this.url, { params: { case_id: caseId } });
  }

  forContact(contactId) {
    return axios.get(this.url, { params: { contact_id: contactId } });
  }

  forConversation(conversationId) {
    return axios.get(this.url, { params: { conversation_id: conversationId } });
  }

  // Plantillas de WhatsApp que el agente puede usar en esa conversación (display_id).
  // `target` es el display_id o, para un contacto sin conversaciones, { contact_id, inbox_id }.
  templates(target) {
    return axios.get(`${this.url}/templates`, { params: targetParams(target) });
  }

  // Fuentes que puede consultar y la nota IA del contacto (mismo `target`).
  context(target) {
    return axios.get(`${this.url}/context`, { params: targetParams(target) });
  }

  // Bandejas por las que se le puede escribir a un contacto sin conversaciones.
  inboxes(contactId) {
    return axios.get(`${this.url}/inboxes`, {
      params: { contact_id: contactId },
    });
  }

  create(params) {
    return axios.post(this.url, { ...params, tz: browserZone() });
  }

  pause(id) {
    return axios.post(`${this.url}/${id}/pause`);
  }

  resume(id) {
    return axios.post(`${this.url}/${id}/resume`);
  }

  cancel(id) {
    return axios.post(`${this.url}/${id}/cancel`);
  }
}

export default new AiFollowUpsAPI();
