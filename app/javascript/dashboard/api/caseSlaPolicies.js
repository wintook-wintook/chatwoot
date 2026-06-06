// @tickets_cases 2I
import ApiClient from './ApiClient';

/* global axios */

class CaseSlaPoliciesAPI extends ApiClient {
  constructor() {
    super('case_sla_policies', { accountScoped: true });
  }

  getAll() {
    return axios.get(this.url);
  }
}

export default new CaseSlaPoliciesAPI();
