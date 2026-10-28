// CrmZeus O1 — organizaciones (clientes / prospectos) y sus consignatarios.
import ApiClient from './ApiClient';

/* global axios */

class CrmOrganizationsAPI extends ApiClient {
  constructor() {
    super('crm/organizations', { accountScoped: true });
  }

  list(params) {
    return axios.get(this.url, { params });
  }

  convert(id) {
    return axios.post(`${this.url}/${id}/convert`);
  }

  consignees(id) {
    return axios.get(`${this.url}/${id}/consignees`);
  }
}

export default new CrmOrganizationsAPI();
