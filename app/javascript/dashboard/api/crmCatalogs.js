// CrmZeus — catálogos de organizaciones. `fetch` trae todos juntos (para el
// formulario); `resource(name)` da el ABC de uno (lookups, sellers, currencies,
// payment_terms); las ciudades se buscan y se dan de alta al vuelo.
import ApiClient from './ApiClient';

/* global axios */

class CrmCatalogsAPI extends ApiClient {
  constructor() {
    super('crm', { accountScoped: true });
  }

  // { lookups: { rating: [...], ... }, sellers, payment_terms, currencies, countries, statuses, can_admin }
  fetch(params) {
    return axios.get(`${this.url}/catalogs`, { params });
  }

  list(resource, params) {
    return axios.get(`${this.url}/${resource}`, { params });
  }

  createItem(resource, key, item) {
    return axios.post(`${this.url}/${resource}`, { [key]: item });
  }

  updateItem(resource, key, id, item) {
    return axios.patch(`${this.url}/${resource}/${id}`, { [key]: item });
  }

  deleteItem(resource, id) {
    return axios.delete(`${this.url}/${resource}/${id}`);
  }

  searchCities(params) {
    return axios.get(`${this.url}/cities`, { params });
  }

  createCity(city) {
    return axios.post(`${this.url}/cities`, { city });
  }
}

export default new CrmCatalogsAPI();
