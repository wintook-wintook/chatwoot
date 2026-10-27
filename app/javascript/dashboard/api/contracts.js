/* global axios */
// Plan-Contratos R1 — contratos (servicios recurrentes) de los clientes.
import ApiClient from './ApiClient';

class ContractsAPI extends ApiClient {
  constructor() {
    super('contracts', { accountScoped: true });
  }

  // { contracts, meta: { count, page, per_page, counts } }
  list(params = {}) {
    return axios.get(this.url, { params });
  }

  create(data) {
    return axios.post(this.url, { contract: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { contract: data });
  }

  registerPayment(id) {
    return axios.post(`${this.url}/${id}/register_payment`);
  }

  renew(id) {
    return axios.post(`${this.url}/${id}/renew`);
  }

  cancel(id, reason) {
    return axios.post(`${this.url}/${id}/cancel`, { reason });
  }

  reactivate(id) {
    return axios.post(`${this.url}/${id}/reactivate`);
  }

  template() {
    return axios.get(`${this.url}/template`, { responseType: 'blob' });
  }

  importCsv(file) {
    const data = new FormData();
    data.append('file', file);
    return axios.post(`${this.url}/import`, data);
  }
}

export default new ContractsAPI();
