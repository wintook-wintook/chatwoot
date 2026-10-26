/* global axios */
// Plan-Trabajo-Campo R4 — equipos del cliente.
import ApiClient from './ApiClient';

class CustomerAssetsAPI extends ApiClient {
  constructor() {
    super('customer_assets', { accountScoped: true });
  }

  forContact(contactId, all = false) {
    return axios.get(this.url, { params: { contact_id: contactId, all } });
  }

  // { customer_asset: {...} } con su historial de órdenes.
  history(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(data) {
    return axios.post(this.url, { customer_asset: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { customer_asset: data });
  }
}

export default new CustomerAssetsAPI();
