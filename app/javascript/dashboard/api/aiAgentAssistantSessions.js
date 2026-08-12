/* global axios */
// ================================================================================
// proyecto@ai_agent_assistant - F5
// ================================================================================
// API Client: AiAgentAssistantSessionsAPI
// Descripción: El chat asistente. Una sesión es una conversación con su borrador.
//   `apply` mueve al borrador SOLO los campos que el usuario aceptó — la regla del
//   módulo es aplicar por campo, nunca en bloque.
// ================================================================================

import ApiClient from './ApiClient';

class AiAgentAssistantSessionsAPI extends ApiClient {
  constructor() {
    super('ai_agent_assistant/sessions', { accountScoped: true });
  }

  // `complementaryPrompt` solo se usa en modo auditar: es el prompt que el usuario
  // trae escrito de fuera y que hay que diseccionar.
  open({ mode, trackingTemplateId, complementaryPrompt } = {}) {
    return axios.post(this.url, {
      mode,
      tracking_template_id: trackingTemplateId || undefined,
      complementary_prompt: complementaryPrompt || undefined,
    });
  }

  send(id, message) {
    return axios.post(`${this.url}/${id}/messages`, { message });
  }

  apply(id, fields) {
    return axios.post(`${this.url}/${id}/apply`, { fields });
  }

  discard(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new AiAgentAssistantSessionsAPI();
