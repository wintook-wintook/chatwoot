// ================================================================================
// @tickets_cases
// ================================================================================
// API Client: CaseTicketsAPI
// Descripción: Cliente HTTP para el Gestor de Tickets (account-scoped)
// ================================================================================

import ApiClient from './ApiClient';

/* global axios */

class CaseTicketsAPI extends ApiClient {
  constructor() {
    super('case_tickets', { accountScoped: true });
  }

  getAll(params = {}) {
    return axios.get(this.url, { params });
  }

  getEvents(ticketId) {
    return axios.get(`${this.url}/${ticketId}/case_events`);
  }

  transition(ticketId, status, reason = null, extra = {}) {
    return axios.patch(`${this.url}/${ticketId}/transition`, {
      status,
      reason,
      ...extra,
    });
  }

  assign(ticketId, params) {
    return axios.patch(`${this.url}/${ticketId}/assign`, params);
  }

  escalate(ticketId, params = {}) {
    return axios.patch(`${this.url}/${ticketId}/escalate`, params);
  }

  getMetrics(params = {}) {
    return axios.get(`${this.url}/metrics`, { params });
  }

  // @tickets_cases 2F — aprobación/rechazo de un cambio
  changeApproval(ticketId, params) {
    return axios.patch(`${this.url}/${ticketId}/change_approval`, params);
  }

  // @tickets_cases 2H — base de conocimiento
  getKbPortals() {
    return axios.get(`${this.url}/kb_portals`);
  }

  generateArticle(ticketId, params) {
    return axios.post(`${this.url}/${ticketId}/generate_article`, params);
  }

  // @tickets_cases 2E — relaciones entre tickets
  getRelations(ticketId) {
    return axios.get(`${this.url}/${ticketId}/relations`);
  }

  createRelation(ticketId, params) {
    return axios.post(`${this.url}/${ticketId}/relations`, params);
  }

  deleteRelation(ticketId, relationId) {
    return axios.delete(`${this.url}/${ticketId}/relations/${relationId}`);
  }

  // @tickets_cases 3B — clasificación sugerida por IA
  applyAiSuggestion(ticketId, fields) {
    return axios.post(`${this.url}/${ticketId}/apply_ai_suggestion`, {
      fields,
    });
  }

  dismissAiSuggestion(ticketId) {
    return axios.delete(`${this.url}/${ticketId}/dismiss_ai_suggestion`);
  }

  // @tickets_cases 3C — respuesta sugerida desde la base de conocimiento
  suggestReply(ticketId) {
    return axios.post(`${this.url}/${ticketId}/suggest_reply`);
  }

  // @tickets_cases 3E — resumen + causa raíz sugerida
  summarize(ticketId) {
    return axios.post(`${this.url}/${ticketId}/summarize`);
  }

  // @tickets_cases 3D — detección de incidentes repetidos
  detectDuplicates(ticketId) {
    return axios.post(`${this.url}/${ticketId}/detect_duplicates`);
  }

  // @tickets_cases 3F — seguimiento sugerido al cliente
  followUp(ticketId) {
    return axios.post(`${this.url}/${ticketId}/follow_up`);
  }

  // @tickets_cases — bloqueo de ticket (evitar choque de agentes)
  lock(ticketId) {
    return axios.patch(`${this.url}/${ticketId}/lock`);
  }

  unlock(ticketId) {
    return axios.patch(`${this.url}/${ticketId}/unlock`);
  }
}

export default new CaseTicketsAPI();
