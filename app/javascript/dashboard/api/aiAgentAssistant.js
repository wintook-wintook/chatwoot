// ================================================================================
// proyecto@ai_agent_assistant - F1
// ================================================================================
// API Client: AiAgentAssistantAPI
// Descripción: Superficie del Asistente de Agentes IA (account-scoped).
//              `capabilities` devuelve el catálogo resuelto contra el estado real
//              de la cuenta: qué directiva está disponible, cuál descarta el
//              prompt y qué modelo usaría el motor en ese inbox.
// ================================================================================

/* global axios */
import ApiClient from './ApiClient';

class AiAgentAssistantAPI extends ApiClient {
  constructor() {
    super('ai_agent_assistant', { accountScoped: true });
  }

  // Valida un borrador. No persiste nada: si se pasa `id`, el backend parte del
  // Agente IA guardado y le aplica encima los campos editados.
  lint(payload) {
    return axios.post(`${this.url}/lint`, payload);
  }

  getCapabilities({ inboxId, trackingTemplateId } = {}) {
    return axios.get(`${this.url}/capabilities`, {
      params: {
        inbox_id: inboxId || undefined,
        tracking_template_id: trackingTemplateId || undefined,
      },
    });
  }
}

export default new AiAgentAssistantAPI();
