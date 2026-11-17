/* global axios */
// Probador de agentes (Agentes IA › Probador): pláticas de prueba con el motor real (1.0 o 2.0),
// el entrenador, los lotes y la bitácora.
import ApiClient from './ApiClient';

class AgentTesterAPI extends ApiClient {
  constructor() {
    super('agent_tester', { accountScoped: true });
  }

  agents() {
    return axios.get(`${this.url}/agents`);
  }

  start(templateId) {
    return axios.post(`${this.url}/sessions`, { template_id: templateId });
  }

  say(conversationId, content) {
    return axios.post(`${this.url}/sessions/${conversationId}/say`, {
      content,
    });
  }

  since(conversationId, after) {
    return axios.get(`${this.url}/sessions/${conversationId}`, {
      params: { after },
    });
  }

  feedback(conversationId, messageId, feedback) {
    return axios.post(`${this.url}/sessions/${conversationId}/feedback`, {
      message_id: messageId,
      feedback,
    });
  }

  apply(logId) {
    return axios.post(`${this.url}/apply`, { log_id: logId });
  }

  fixSource(cannedId, content) {
    return axios.post(`${this.url}/fix_source`, {
      canned_id: cannedId,
      content,
    });
  }

  logs() {
    return axios.get(`${this.url}/logs`);
  }
}

export default new AgentTesterAPI();
