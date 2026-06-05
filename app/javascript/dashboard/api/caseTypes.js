// @tickets_cases
import ApiClient from './ApiClient';

class CaseTypesAPI extends ApiClient {
  constructor() {
    super('case_types', { accountScoped: true });
  }

  getAll() {
    return axios.get(this.url);
  }
}

export default new CaseTypesAPI();
