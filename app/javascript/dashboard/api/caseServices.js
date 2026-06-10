// @tickets_cases 2B
import ApiClient from './ApiClient';

class CaseServicesAPI extends ApiClient {
  constructor() {
    super('case_services', { accountScoped: true });
  }

  getAll() {
    return axios.get(this.url);
  }
}

export default new CaseServicesAPI();
