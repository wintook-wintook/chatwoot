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

  // Retomar en vez de empezar de cero: el borrador es el producto y perderlo al
  // cerrar el cajón o al cambiar de pestaña era el defecto.
  list(trackingTemplateId) {
    return axios.get(this.url, {
      params: { tracking_template_id: trackingTemplateId || undefined },
    });
  }

  get(id) {
    return axios.get(`${this.url}/${id}`);
  }

  // Cambia el encuadre SIN tocar la conversación ni el borrador.
  setMode(id, mode) {
    return axios.patch(`${this.url}/${id}`, { mode });
  }

  // Edita el borrador a mano. Hay campos —el nombre— que uno ya sabe y no tiene
  // sentido esperar a que el asistente los proponga.
  setDraft(id, draft) {
    return axios.patch(`${this.url}/${id}`, { draft });
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
