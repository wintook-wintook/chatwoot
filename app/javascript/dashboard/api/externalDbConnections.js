// @query_databases — API de conexiones a ERPs (account-scoped, admin)
import ApiClient from './ApiClient';

/* global axios */

class ExternalDbConnectionsAPI extends ApiClient {
  constructor() {
    super('external_db_connections', { accountScoped: true });
  }

  testConnection(id) {
    return axios.post(`${this.url}/${id}/test_connection`);
  }
}

export default new ExternalDbConnectionsAPI();
