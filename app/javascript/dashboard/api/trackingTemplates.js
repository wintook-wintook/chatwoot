// ================================================================================
// proyecto@tracking_templates
// ================================================================================
// API Client: TrackingTemplatesAPI
// Descripción: Cliente API para plantillas de seguimiento (account-scoped)
// ================================================================================

/* global axios */
import ApiClient from './ApiClient';

class TrackingTemplatesAPI extends ApiClient {
  constructor() {
    super('tracking_templates', { accountScoped: true });
  }

  getCalendarIntegrations() {
    return axios.get(`${this.url}/calendar_integrations`);
  }

  // proyecto@ai_agent_assistant — ramificar. La copia se hace en el backend porque
  // el nombre es único por cuenta y hay adjuntos que arrastrar; hacerla aquí daría
  // una copia sin sus archivos y con el error de unicidad en crudo.
  duplicate(id, name) {
    return axios.post(`${this.url}/${id}/duplicate`, {
      name: name || undefined,
    });
  }
}

export default new TrackingTemplatesAPI();
