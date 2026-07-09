// @query_databases — API de consultas predefinidas, anidadas a una conexión (admin)
import ApiClient from './ApiClient';

/* global axios */

class ExternalDbQueriesAPI extends ApiClient {
  constructor() {
    super('external_db_connections', { accountScoped: true });
  }

  nestedUrl(connectionId) {
    return `${this.url}/${connectionId}/external_db_queries`;
  }

  getByConnection(connectionId) {
    return axios.get(this.nestedUrl(connectionId));
  }

  createQuery(connectionId, query) {
    return axios.post(this.nestedUrl(connectionId), {
      external_db_query: query,
    });
  }

  updateQuery(connectionId, id, query) {
    return axios.patch(`${this.nestedUrl(connectionId)}/${id}`, {
      external_db_query: query,
    });
  }

  deleteQuery(connectionId, id) {
    return axios.delete(`${this.nestedUrl(connectionId)}/${id}`);
  }
}

export default new ExternalDbQueriesAPI();
