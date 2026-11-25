/* global axios */
// Plan-Catalogo-Cotizaciones V1 — Ventas › Cotizaciones.
import ApiClient from './ApiClient';

class QuotesAPI extends ApiClient {
  constructor() {
    super('quotes', { accountScoped: true });
  }

  // params: { status, q, assignee_id, contact_id, opportunity_id, origin_ticket_id, page }
  list(params = {}) {
    return axios.get(this.url, { params });
  }

  summary() {
    return axios.get(`${this.url}/summary`);
  }

  // Retenciones: { apply } si el cliente (o su organización) es persona moral.
  withholdingsDefault(params) {
    return axios.get(`${this.url}/withholdings_default`, { params });
  }

  // payload: { quote: {...}, items: [...], create_opportunity }
  createQuote(payload) {
    return axios.post(this.url, payload);
  }

  updateQuote(id, payload) {
    return axios.patch(`${this.url}/${id}`, payload);
  }

  transition(id, to, extra = {}) {
    return axios.post(`${this.url}/${id}/transition`, { to, ...extra });
  }

  newVersion(id) {
    return axios.post(`${this.url}/${id}/new_version`);
  }

  linkOpportunity(id, payload) {
    return axios.post(`${this.url}/${id}/link_opportunity`, payload);
  }

  deliver(id) {
    return axios.post(`${this.url}/${id}/deliver`);
  }
}

export default new QuotesAPI();
