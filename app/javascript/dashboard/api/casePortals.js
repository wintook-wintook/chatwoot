// @tickets_cases — User Portal
import ApiClient from './ApiClient';

class CasePortalsAPI extends ApiClient {
  constructor() {
    super('case_portals', { accountScoped: true });
  }
}

export default new CasePortalsAPI();
