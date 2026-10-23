/* global axios */
// feat/licencias (F2b) — gestión de licencias. El servidor solo responde desde una
// cuenta de Wintook y a quien tenga «Ver licencias» (escribir: «Gestionar»).
import ApiClient from './ApiClient';

class LicensesAPI extends ApiClient {
  constructor() {
    super('licenses', { accountScoped: true });
  }

  getPlans() {
    return axios.get(`${this.url}/plans`);
  }

  createPlan(plan) {
    return axios.post(`${this.url}/plans`, { plan });
  }

  updatePlan(id, plan) {
    return axios.patch(`${this.url}/plans/${id}`, { plan });
  }

  // { estado, dias, q, page, per_page }
  getAccounts(params) {
    return axios.get(`${this.url}/accounts`, { params });
  }

  getAccount(id) {
    return axios.get(`${this.url}/accounts/${id}`);
  }

  // { target_account_id, license_plan_id, start, max_agents, duration_days, name, notes }
  issue(payload) {
    return axios.post(`${this.url}/account_licenses`, payload);
  }

  cancel(id) {
    return axios.post(`${this.url}/account_licenses/${id}/cancel`);
  }
}

export default new LicensesAPI();
