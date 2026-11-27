/* global axios */
// Agentes listos: los puestos empaquetados que la empresa activa en sus bandejas.
import ApiClient from './ApiClient';

class ReadyAgentsAPI extends ApiClient {
  constructor() {
    super('ready_agents', { accountScoped: true });
  }

  // Chat de prueba con lo que hay en el asistente (motor 2.0):
  // { reply, tools, decision, trace, state }. `state` es la memoria del cliente de la prueba.
  test(readyAgent, messages, { id = null, state = {} } = {}) {
    return axios.post(`${this.url}/test`, {
      ready_agent: readyAgent,
      messages,
      id,
      state,
    });
  }

  // Sugerencias con «Tu negocio»: kind 'areas' → { support: { yes, no }, … } · 'questions' → { questions }.
  suggest(kind, settings, areas = []) {
    return axios.post(`${this.url}/suggest`, {
      kind,
      business_what: settings.business_what,
      business_who: settings.business_who,
      areas,
    });
  }

  // «Atención a prospectos»: { total, results, conversion, drop_off: [{ question, count }], ads: [...] }.
  metrics(id) {
    return axios.get(`${this.url}/${id}/metrics`);
  }

  // «Atención a clientes» › Probar la matriz: { rows: [{ example, area, kind, got, ok }] }.
  matrix(readyAgent, { id = null } = {}) {
    return axios.post(`${this.url}/matrix`, { ready_agent: readyAgent, id });
  }
}

export default new ReadyAgentsAPI();
