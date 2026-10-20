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

  // @tickets_cases — mueve el ticket a una columna del Kanban por tipo (A+). `closure`
  // es opcional: se manda cuando el movimiento aterriza en `closed` (el backend lo
  // exige, ver `requires_closure` en la respuesta de error si falta).
  // Plan-Clase-Comercial F4 — `extra` lleva `postponed_until` al soltar una
  // oportunidad en la columna de espera (`requires_postpone`).
  move(ticketId, caseTypeColumnId, closure, extra = {}) {
    return axios.patch(`${this.url}/${ticketId}/move`, {
      case_type_column_id: caseTypeColumnId,
      ...(closure ? { closure } : {}),
      ...extra,
    });
  }

  // Plan-Clase-Comercial F4 — oportunidades: cerrar con resultado, posponer, retomar.
  closeWithOutcome(ticketId, params) {
    return axios.patch(`${this.url}/${ticketId}/outcome`, params);
  }

  postpone(ticketId, params) {
    return axios.patch(`${this.url}/${ticketId}/postpone`, params);
  }

  // Plan-Clase-Orden-de-Trabajo F2a — materiales de una orden de trabajo.
  createWorkOrderItem(ticketId, item) {
    return axios.post(`${this.url}/${ticketId}/work_order_items`, {
      work_order_item: item,
    });
  }

  updateWorkOrderItem(ticketId, itemId, item) {
    return axios.patch(`${this.url}/${ticketId}/work_order_items/${itemId}`, {
      work_order_item: item,
    });
  }

  deleteWorkOrderItem(ticketId, itemId) {
    return axios.delete(`${this.url}/${ticketId}/work_order_items/${itemId}`);
  }

  // Plan-Clase-Orden-de-Trabajo F2b — orden de trabajo nueva desde un caso.
  createWorkOrder(ticketId, caseTypeId) {
    return axios.post(`${this.url}/${ticketId}/work_order`, {
      case_type_id: caseTypeId,
    });
  }

  // Plan-Clase-Proyecto P2 — proyecto nuevo desde una oportunidad ganada.
  createProject(ticketId, caseTypeId) {
    return axios.post(`${this.url}/${ticketId}/project`, {
      case_type_id: caseTypeId,
    });
  }

  // Plan-Clase-Proyecto P2 — casos dentro de un proyecto.
  getProjectChildren(projectId) {
    return axios.get(`${this.url}/${projectId}/project_children`);
  }

  // `payload`: { case_type_id, title } (crear) o { ticket_id } (ligar).
  addProjectChild(projectId, payload) {
    return axios.post(`${this.url}/${projectId}/project_children`, payload);
  }

  // Plan-Clase-Proyecto P3 — hitos y casos con fecha para la línea de tiempo.
  getProjectTimeline(projectId) {
    return axios.get(`${this.url}/${projectId}/project_children/timeline`);
  }

  removeProjectChild(projectId, childId) {
    return axios.delete(`${this.url}/${projectId}/project_children/${childId}`);
  }

  resume(ticketId, params = {}) {
    return axios.patch(`${this.url}/${ticketId}/resume`, params);
  }

  assign(ticketId, params) {
    return axios.patch(`${this.url}/${ticketId}/assign`, params);
  }

  escalate(ticketId, params = {}) {
    return axios.patch(`${this.url}/${ticketId}/escalate`, params);
  }

  // @tickets_cases — reapertura de un ticket cerrado (motivo obligatorio)
  reopen(ticketId, reason) {
    return axios.patch(`${this.url}/${ticketId}/reopen`, { reason });
  }

  getMetrics(params = {}) {
    return axios.get(`${this.url}/metrics`, { params });
  }

  // @tickets_cases P3 — acciones en lote desde la cola
  bulk(params) {
    return axios.post(`${this.url}/bulk`, params);
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
