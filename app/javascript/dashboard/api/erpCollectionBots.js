// @query_databases — API de bots cobradores (account-scoped, admin)
import ApiClient from './ApiClient';

/* global axios */

class ErpCollectionBotsAPI extends ApiClient {
  constructor() {
    super('erp_collection_bots', { accountScoped: true });
  }

  preview(id) {
    return axios.post(`${this.url}/${id}/preview`);
  }
}

export default new ErpCollectionBotsAPI();
