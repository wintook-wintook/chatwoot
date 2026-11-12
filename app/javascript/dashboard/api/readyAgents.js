/* global axios */
// Agentes listos: los puestos empaquetados que la empresa activa en sus bandejas.
import ApiClient from './ApiClient';

class ReadyAgentsAPI extends ApiClient {
  constructor() {
    super('ready_agents', { accountScoped: true });
  }

  // Chat de prueba con lo que hay en el formulario: { reply, tools, decision, answers }.
  test(readyAgent, messages) {
    return axios.post(`${this.url}/test`, {
      ready_agent: readyAgent,
      messages,
    });
  }
}

export default new ReadyAgentsAPI();
