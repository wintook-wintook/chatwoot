// ================================================================================
// proyecto@tracking_templates
// ================================================================================
// API Client: TrackingTemplatesAPI
// Descripción: Cliente API para plantillas de seguimiento (account-scoped)
// ================================================================================

import ApiClient from './ApiClient';

class TrackingTemplatesAPI extends ApiClient {
  constructor() {
    super('tracking_templates', { accountScoped: true });
  }

  getCalendarIntegrations() {
    return axios.get(`${this.url}/calendar_integrations`);
  }
}

export default new TrackingTemplatesAPI();
