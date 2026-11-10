/* global axios */
// Presupuesto de ventas — metas por vendedor y vendedor + cliente, y su avance.
import ApiClient from './ApiClient';

class SalesBudgetsAPI extends ApiClient {
  constructor() {
    super('sales_budgets', { accountScoped: true });
  }

  // { year, currency, kind: 'seller' | 'seller_client', user_id }
  list(params) {
    return axios.get(this.url, { params });
  }

  // lines: [{ user_id, organization_id | contact_id, period: 'YYYY-MM', amount }]
  save({ year, currency, lines }) {
    return axios.put(`${this.url}/bulk`, { year, currency, lines });
  }

  copy({ fromYear, toYear, currency, percent }) {
    return axios.post(`${this.url}/copy`, {
      from_year: fromYear,
      to_year: toYear,
      currency,
      percent,
    });
  }

  removeClient({ year, currency, userId, organizationId, contactId }) {
    return axios.delete(`${this.url}/client`, {
      data: {
        year,
        currency,
        user_id: userId,
        organization_id: organizationId,
        contact_id: contactId,
      },
    });
  }

  // { from: 'YYYY-MM', to: 'YYYY-MM', currency }
  report(params) {
    return axios.get(`${this.url}/report`, { params });
  }
}

export default new SalesBudgetsAPI();
