// @tickets_cases
import ApiClient from './ApiClient';

/* global axios */

// Recurso singular (una config por cuenta) → no usa :id.
class CaseFolioConfigAPI extends ApiClient {
  constructor() {
    super('case_folio_config', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  updateConfig(data) {
    return axios.patch(this.url, { case_folio_config: data });
  }
}

export default new CaseFolioConfigAPI();
