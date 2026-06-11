// @tickets_cases 2B
import ApiClient from './ApiClient';

class CaseCategoriesAPI extends ApiClient {
  constructor() {
    super('case_categories', { accountScoped: true });
  }

  getAll() {
    return axios.get(this.url);
  }
}

export default new CaseCategoriesAPI();
