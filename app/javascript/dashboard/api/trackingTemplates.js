/* global axios */
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

  // proyecto@asistente_agentes_ia — Entrenamiento por secciones
  // (docs/formulario_entrenamiento_plan.md).
  getSectionTitles() {
    return axios.get(`${this.url}/section_titles`);
  }

  // { text } o { training_structure } → { text, training_structure, validation }.
  // proyecto@asistente_agentes_ia — las ramas que la cuenta ya escribió, para copiar
  // una a un agente nuevo (ver TrainingRouteCatalog).
  getRouteCatalog() {
    return axios.get(`${this.url}/route_catalog`);
  }

  trainingPreview(payload) {
    return axios.post(`${this.url}/training_preview`, payload);
  }
}

export default new TrackingTemplatesAPI();
