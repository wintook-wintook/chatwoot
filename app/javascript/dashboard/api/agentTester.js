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

  // «En prueba»: el agente sale en el probador.
  setTesting(templateId, on) {
    return axios.post(`${this.url}/agents/${templateId}/testing`, { on });
  }

  // seleccion: 'on' | 'off' | '' — la búsqueda de predefinidas solo en esta plática.
  start(templateId, seleccion = '') {
    return axios.post(`${this.url}/sessions`, {
      template_id: templateId,
      seleccion: seleccion || undefined,
    });
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

  // 👎: lo que debió responder (y, opcional, qué estuvo mal). now: el diagnóstico al momento
  // (solo quien cambia agentes); si no, queda para «Revisión».
  feedback(conversationId, messageId, feedback, note = '', now = false) {
    return axios.post(`${this.url}/sessions/${conversationId}/feedback`, {
      message_id: messageId,
      feedback,
      note: note || undefined,
      now: now || undefined,
    });
  }

  // 👍: la respuesta queda como prueba a cuidar.
  good(conversationId, messageId) {
    return axios.post(`${this.url}/sessions/${conversationId}/good`, {
      message_id: messageId,
    });
  }

  // «Revisión» (quien entrena).
  review(params = {}) {
    return axios.get(`${this.url}/review`, { params });
  }

  reviewConversation(conversationId) {
    return axios.get(`${this.url}/review/${conversationId}`);
  }

  dismiss(logId, reason) {
    return axios.post(`${this.url}/logs/${logId}/dismiss`, { reason });
  }

  rediagnose(logId, note) {
    return axios.post(`${this.url}/logs/${logId}/rediagnose`, { note });
  }

  retestGroup(ids) {
    return axios.post(`${this.url}/logs/retest_group`, { ids });
  }

  // La plática como prueba: va sola al lote del agente y del día.
  saveCase(conversationId, expected) {
    return axios.post(`${this.url}/sessions/${conversationId}/save_case`, {
      expected,
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

  // proyecto@predefinidas_que_contestan: arreglos de un clic desde el 👎.
  fixKind(cannedId, kind) {
    return axios.post(`${this.url}/fix_kind`, { canned_id: cannedId, kind });
  }

  fixStart(cannedId, text) {
    return axios.post(`${this.url}/fix_start`, { canned_id: cannedId, text });
  }

  logs() {
    return axios.get(`${this.url}/logs`);
  }

  // «Ya lo corregí»: corre otra vez la prueba de ese 👎.
  retest(logId) {
    return axios.post(`${this.url}/logs/${logId}/retest`);
  }

  // La plática completa, para seguirla desde la bitácora.
  history(conversationId) {
    return axios.get(`${this.url}/sessions/${conversationId}/history`);
  }
}

export default new AgentTesterAPI();
