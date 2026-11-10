// CrmZeus Q2 — cotizaciones: lista, borrador (`draft` con los defaults del cliente),
// alta/edición, cálculo sin guardar, estatus y duplicar.
import ApiClient from './ApiClient';

/* global axios */

class CrmQuotesAPI extends ApiClient {
  constructor() {
    super('crm/quotes', { accountScoped: true });
  }

  list(params) {
    return axios.get(this.url, { params });
  }

  draft(organizationId) {
    return axios.get(`${this.url}/new`, {
      params: organizationId ? { organization_id: organizationId } : {},
    });
  }

  calculate(quote) {
    return axios.post(`${this.url}/calculate`, { quote });
  }

  changeStatus(id, status) {
    return axios.post(`${this.url}/${id}/status`, { status });
  }

  duplicate(id) {
    return axios.post(`${this.url}/${id}/duplicate`);
  }
}

export default new CrmQuotesAPI();
