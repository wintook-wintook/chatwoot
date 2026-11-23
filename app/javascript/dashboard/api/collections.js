/* global axios */
// Cobranza: la cartera por cortes (Excel/CSV hoy; los sistemas administrativos después) y su agente.
import ApiClient from './ApiClient';

class CollectionsAPI extends ApiClient {
  constructor() {
    super('collections', { accountScoped: true });
  }

  overview() {
    return axios.get(`${this.url}/overview`);
  }

  templateUrl() {
    return `${this.url}/template`;
  }

  downloadTemplate() {
    return axios.get(`${this.url}/template`, { responseType: 'blob' });
  }

  preview(file, mapping) {
    return axios.post(`${this.url}/preview`, this.form(file, mapping));
  }

  apply(file, mapping) {
    return axios.post(`${this.url}/imports`, this.form(file, mapping));
  }

  // eslint-disable-next-line class-methods-use-this
  form(file, mapping) {
    const data = new FormData();
    data.append('file', file);
    Object.entries(mapping || {}).forEach(([field, header]) => {
      if (header) data.append(`mapping[${field}]`, header);
    });
    return data;
  }

  imports() {
    return axios.get(`${this.url}/imports`);
  }

  customers(params) {
    return axios.get(`${this.url}/customers`, { params });
  }

  customer(id) {
    return axios.get(`${this.url}/customers/${id}`);
  }

  link(id, contactId) {
    return axios.post(`${this.url}/customers/${id}/link`, {
      contact_id: contactId,
    });
  }

  createCustomer(id) {
    return axios.post(`${this.url}/customers/${id}/create`);
  }

  ignore(id) {
    return axios.post(`${this.url}/customers/${id}/ignore`);
  }

  createPending() {
    return axios.post(`${this.url}/customers/create_pending`);
  }

  promises(params) {
    return axios.get(`${this.url}/promises`, { params });
  }

  claims(params) {
    return axios.get(`${this.url}/claims`, { params });
  }

  reviewClaim(id, decision, note) {
    return axios.post(`${this.url}/claims/${id}/review`, { decision, note });
  }
}

export default new CollectionsAPI();
