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

  // «Ver prompt»: ensambla lo que recibiría el modelo en las dos rutas.
  previewPrompt(payload) {
    return axios.post(`${this.url}/preview_prompt`, payload);
  }

  // F6: la biblioteca de bloques, resuelta contra la cuenta Y contra el prompt en
  // curso — de ahí que el prompt viaje en la petición.
  patterns({ complementaryPrompt, inboxId, trackingTemplateId } = {}) {
    return axios.get(`${this.url}/patterns`, {
      params: {
        complementary_prompt: complementaryPrompt || undefined,
        inbox_id: inboxId || undefined,
        tracking_template_id: trackingTemplateId || undefined,
      },
    });
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
