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
}

export default new TrackingTemplatesAPI();
