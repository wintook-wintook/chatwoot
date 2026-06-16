// ================================================================================
// proyecto@contact_tracking
// /home/chatwoot/chatwoot/app/javascript/dashboard/api/contactTrackings.js
// ================================================================================
// API Client: contactTrackings
// Descripción: Cliente HTTP para comunicación con el backend de seguimientos
// ⭐ MODIFICADO: Usa accountId explícito desde el store (más robusto)
// ================================================================================

/* global axios */

const API_VERSION = '/api/v1';

class ContactTrackingsAPI {
  // ⭐ Construye la URL base con accountId explícito
  buildUrl(accountId, contactId, suffix = '') {
    return `${API_VERSION}/accounts/${accountId}/contacts/${contactId}/contact_trackings${suffix}`;
  }

  get(accountId, contactId, params = {}) {
    const url = this.buildUrl(accountId, contactId);
    return axios.get(url, { params });
  }

  create(accountId, contactId, data) {
    const url = this.buildUrl(accountId, contactId);
    return axios.post(url, data);
  }

  update(accountId, contactId, trackingId, data) {
    const url = this.buildUrl(accountId, contactId, `/${trackingId}`);
    return axios.patch(url, data);
  }

  pause(accountId, contactId, trackingId) {
    const url = this.buildUrl(accountId, contactId, `/${trackingId}/pause`);
    return axios.post(url);
  }

  resume(accountId, contactId, trackingId, data = {}) {
    const url = this.buildUrl(accountId, contactId, `/${trackingId}/resume`);
    return axios.post(url, data);
  }

  cancel(accountId, contactId, trackingId) {
    const url = this.buildUrl(accountId, contactId, `/${trackingId}/cancel`);
    return axios.post(url);
  }

  improveText(accountId, contactId, text, mode = 'improve', context = '', objective = '') {
    const url = this.buildUrl(accountId, contactId, '/improve_text');
    return axios.post(url, { text, mode, context, objective });
  }

  // proyecto@contact_tracking — Dashboard: agregados a nivel cuenta
  getOverview(accountId, params = {}) {
    const url = `${API_VERSION}/accounts/${accountId}/contact_trackings/overview`;
    return axios.get(url, { params });
  }

  // proyecto@contact_tracking — Dashboard: listado filtrable/paginado
  getList(accountId, params = {}) {
    const url = `${API_VERSION}/accounts/${accountId}/contact_trackings/list`;
    return axios.get(url, { params });
  }
}

export default new ContactTrackingsAPI();
