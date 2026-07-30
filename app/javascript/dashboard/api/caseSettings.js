// @tickets_cases — Ajustes del módulo (modo simple/ITIL)
import ApiClient from './ApiClient';

class CaseSettingsAPI extends ApiClient {
  constructor() {
    super('case_setting', { accountScoped: true });
  }

  show() {
    return axios.get(this.url);
  }

  updateSettings(data) {
    return axios.patch(this.url, data);
  }
}

export default new CaseSettingsAPI();
