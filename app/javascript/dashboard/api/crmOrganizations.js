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

  // CrmZeus C1 — contactos de Wintook ligados a la organización.
  contacts(id) {
    return axios.get(`${this.url}/${id}/contacts`);
  }

  searchContacts(id, q) {
    return axios.get(`${this.url}/${id}/contacts/search`, { params: { q } });
  }

  linkContact(id, contactId) {
    return axios.post(`${this.url}/${id}/contacts`, { contact_id: contactId });
  }

  unlinkContact(id, contactId) {
    return axios.delete(`${this.url}/${id}/contacts/${contactId}`);
  }
}

export default new CrmOrganizationsAPI();
