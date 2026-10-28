/* global axios */
// Plan-Trabajo-Campo R1 — reporte de servicio de la orden de trabajo.
import ApiClient from './ApiClient';

class ServiceReportsAPI extends ApiClient {
  constructor() {
    super('case_tickets', { accountScoped: true });
  }

  base(ticketId) {
    return `${this.url}/${ticketId}/service_report`;
  }

  fetch(ticketId) {
    return axios.get(this.base(ticketId));
  }

  setOnSite(ticketId, onSite) {
    return axios.patch(this.base(ticketId), { on_site: onSite });
  }

  // Plan-Trabajo-Campo R5 — técnico externo: enlace sin usuario hasta terminar la visita.
  externalLink(ticketId, { name, phone }) {
    return axios.post(`${this.base(ticketId)}/external_link`, { name, phone });
  }

  revokeExternalLink(ticketId) {
    return axios.delete(`${this.base(ticketId)}/external_link`);
  }

  // Plan-Trabajo-Campo R4 — equipo del cliente sobre el que se hace la orden.
  setAsset(ticketId, assetId) {
    return axios.patch(this.base(ticketId), { customer_asset_id: assetId });
  }

  // { kind: note|photo|document, tag: before|after, content, file }
  addLog(ticketId, { kind, tag, content, file }) {
    const data = new FormData();
    data.append('kind', kind);
    if (tag) data.append('tag', tag);
    if (content) data.append('content', content);
    if (file) data.append('file', file);
    return axios.post(`${this.base(ticketId)}/logs`, data);
  }

  removeLog(ticketId, id) {
    return axios.delete(`${this.base(ticketId)}/logs/${id}`);
  }

  timer(ticketId, action) {
    return axios.post(`${this.base(ticketId)}/timer`, { timer_action: action });
  }

  addTime(ticketId, payload) {
    return axios.post(`${this.base(ticketId)}/time_entries`, payload);
  }

  removeTime(ticketId, id) {
    return axios.delete(`${this.base(ticketId)}/time_entries/${id}`);
  }

  deliver(ticketId) {
    return axios.post(`${this.base(ticketId)}/deliver`);
  }
}

export default new ServiceReportsAPI();
