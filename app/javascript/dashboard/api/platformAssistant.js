/* global axios */
// Asistente (Dali) — el asistente conversacional de toda la plataforma. Archivo
// aparte de api/assistant.js, que es el Asistente de Agentes IA (Entrenamiento).
import ApiClient from './ApiClient';
import { browserZone } from './fieldVisits';

class AssistantAPI extends ApiClient {
  constructor() {
    super('assistant', { accountScoped: true });
  }

  show() {
    return axios.get(this.url, { params: { tz: browserZone() } });
  }

  // `context`: lo que el usuario está viendo (página, caso, contacto…).
  send(content, context) {
    return axios.post(`${this.url}/messages`, {
      content,
      context,
      tz: browserZone(),
    });
  }

  reset() {
    return axios.post(`${this.url}/reset`);
  }

  confirm(proposalId, payload) {
    return axios.post(`${this.url}/proposals/${proposalId}/confirm`, {
      payload,
      tz: browserZone(),
    });
  }

  cancel(proposalId) {
    return axios.post(`${this.url}/proposals/${proposalId}/cancel`);
  }

  rename(name) {
    return axios.patch(`${this.url}/settings`, { name });
  }
}

export default new AssistantAPI();
