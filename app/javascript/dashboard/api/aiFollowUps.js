/* global axios */
// Seguimiento IA — el agente nuevo con herramientas («Delegar a agente» en el caso).
import ApiClient from './ApiClient';
import { browserZone } from './fieldVisits';

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
  templates(conversationId) {
    return axios.get(`${this.url}/templates`, {
      params: { conversation_id: conversationId },
    });
  }

  // Fuentes que puede consultar y la nota IA del contacto de esa conversación (display_id).
  context(conversationId) {
    return axios.get(`${this.url}/context`, {
      params: { conversation_id: conversationId },
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
