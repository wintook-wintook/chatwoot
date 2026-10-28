// CrmZeus — organizaciones (clientes / prospectos) y sus consignatarios.
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

  createConsignee(id, consignee) {
    return axios.post(`${this.url}/${id}/consignees`, { consignee });
  }

  updateConsignee(id, consigneeId, consignee) {
    return axios.patch(`${this.url}/${id}/consignees/${consigneeId}`, {
      consignee,
    });
  }

  deleteConsignee(id, consigneeId) {
    return axios.delete(`${this.url}/${id}/consignees/${consigneeId}`);
  }
}

export default new CrmOrganizationsAPI();
