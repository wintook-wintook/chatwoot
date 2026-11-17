/* global axios */
// Motor 2.0 de Agentes a medida: la ficha 2.0, su probador y sus versiones.
import ApiClient from './ApiClient';

class Motor2AgentsAPI extends ApiClient {
  constructor() {
    super('motor2_agents', { accountScoped: true });
  }

  options(inboxId) {
    return axios.get(`${this.url}/options`, {
      params: inboxId ? { inbox_id: inboxId } : {},
    });
  }

  // Chat de prueba con lo que hay en la pantalla: { reply, trace, decision, state, files }.
  test({ id, agent, messages, state }) {
    return axios.post(`${this.url}/test`, { id, agent, messages, state });
  }

  readiness(id) {
    return axios.get(`${this.url}/${id}/readiness`);
  }

  activate(id) {
    return axios.post(`${this.url}/${id}/activate`);
  }

  versions(id) {
    return axios.get(`${this.url}/${id}/versions`);
  }

  tests(id) {
    return axios.get(`${this.url}/${id}/tests`);
  }

  saveTest(id, { name, turns, expected }) {
    return axios.post(`${this.url}/${id}/tests`, { name, turns, expected });
  }

  deleteTest(id, testId) {
    return axios.delete(`${this.url}/${id}/tests/${testId}`);
  }

  runTests(id, testId) {
    return axios.post(
      `${this.url}/${id}/tests/run`,
      testId ? { test_id: testId } : {}
    );
  }

  // 👎: el entrenador dice dónde estuvo el error (agente, fuente o motor) y qué hizo.
  correct(id, { messages, reply, feedback, trace }) {
    return axios.post(`${this.url}/${id}/tests/correct`, {
      messages,
      reply,
      feedback,
      trace,
    });
  }

  fixSource(id, { cannedId, content }) {
    return axios.post(`${this.url}/${id}/tests/fix_source`, {
      canned_id: cannedId,
      content,
    });
  }

  restore(id, versionId) {
    return axios.post(`${this.url}/${id}/restore`, { version_id: versionId });
  }
}

export default new Motor2AgentsAPI();
