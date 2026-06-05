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

  transition(ticketId, status, reason = null) {
    return axios.patch(`${this.url}/${ticketId}/transition`, { status, reason });
  }

  assign(ticketId, params) {
    return axios.patch(`${this.url}/${ticketId}/assign`, params);
  }

  getMetrics(params = {}) {
    return axios.get(`${this.url}/metrics`, { params });
  }
}

export default new CaseTicketsAPI();
