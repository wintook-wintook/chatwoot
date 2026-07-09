// @query_databases — API de la consola (ejecutar consulta predefinida; agente)
import ApiClient from './ApiClient';

/* global axios */

class ExternalDbConsoleAPI extends ApiClient {
  constructor() {
    super('external_db_console', { accountScoped: true });
  }

  getCatalog() {
    return axios.get(`${this.url}/catalog`);
  }

  run({ queryId, params }) {
    return axios.post(`${this.url}/run`, { query_id: queryId, params });
  }

  ask({ connectionId, question }) {
    return axios.post(`${this.url}/ask`, {
      connection_id: connectionId,
      question,
    });
  }
}

export default new ExternalDbConsoleAPI();
