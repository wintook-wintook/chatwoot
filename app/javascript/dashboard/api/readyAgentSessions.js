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
}

export default new ReadyAgentSessionsAPI();
