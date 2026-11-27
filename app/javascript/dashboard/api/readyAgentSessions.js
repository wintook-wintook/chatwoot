/* global axios */
// El agente listo en una conversación: quién atiende, pausar y reanudar.
import ApiClient from './ApiClient';

class ReadyAgentSessionsAPI extends ApiClient {
  constructor() {
    super('ready_agent_sessions', { accountScoped: true });
  }

  forConversation(conversationId) {
    return axios.get(this.url, { params: { conversation_id: conversationId } });
  }

  pause(id) {
    return axios.patch(`${this.url}/${id}/pause`);
  }

  resume(id) {
    return axios.patch(`${this.url}/${id}/resume`);
  }

  // No más recordatorios de su seguimiento corto (alguien del equipo lo va a atender).
  cancelFollowUp(id) {
    return axios.patch(`${this.url}/${id}/cancel_follow_up`);
  }
}

export default new ReadyAgentSessionsAPI();
