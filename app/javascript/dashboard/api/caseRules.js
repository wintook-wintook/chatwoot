// @tickets_cases
import ApiClient from './ApiClient';

class CaseRulesAPI extends ApiClient {
  constructor() {
    super('case_rules', { accountScoped: true });
  }

  getAll() {
    return axios.get(this.url);
  }
}

export default new CaseRulesAPI();
