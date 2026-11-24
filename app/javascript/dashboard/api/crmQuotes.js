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

  // `quoteId` de una cotización ya guardada: el servidor respeta los impuestos guardados.
  calculate(quote, quoteId) {
    return axios.post(`${this.url}/calculate`, {
      quote,
      ...(quoteId ? { quote_id: quoteId } : {}),
    });
  }

  changeStatus(id, status) {
    return axios.post(`${this.url}/${id}/status`, { status });
  }

  // `quote`: lo que hay en pantalla (sin guardar); sin él se duplica lo guardado.
  duplicate(id, quote) {
    return axios.post(`${this.url}/${id}/duplicate`, quote ? { quote } : {});
  }
}

export default new CrmQuotesAPI();
