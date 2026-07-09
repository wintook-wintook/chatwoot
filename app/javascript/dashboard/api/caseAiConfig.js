// ================================================================================
// @tickets_cases 3A
// ================================================================================
// API Client: CaseAiConfigAPI — configuración de IA por cuenta (singular).
// ================================================================================

/* global axios */
import ApiClient from './ApiClient';

class CaseAiConfigAPI extends ApiClient {
  constructor() {
    super('case_ai_config', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  updateConfig(payload) {
    return axios.patch(this.url, { case_ai_config: payload });
  }
}

export default new CaseAiConfigAPI();
