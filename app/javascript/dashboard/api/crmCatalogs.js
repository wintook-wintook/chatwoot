// CrmZeus O1 — catálogos del formulario de organizaciones en una sola llamada.
import ApiClient from './ApiClient';

/* global axios */

class CrmCatalogsAPI extends ApiClient {
  constructor() {
    super('crm/catalogs', { accountScoped: true });
  }

  // { lookups: { rating: [...], ... }, sellers, payment_terms, currencies, countries, statuses, can_admin }
  fetch(params) {
    return axios.get(this.url, { params });
  }
}

export default new CrmCatalogsAPI();
