/* global axios */
// diag/waba F2 — pestaña «Diagnóstico» de una bandeja de WhatsApp Cloud.
import ApiClient from './ApiClient';

class WhatsappHealthAPI extends ApiClient {
  constructor() {
    super('whatsapp/health_checks', { accountScoped: true });
  }

  // Último diagnóstico guardado: { checked_at, checks }.
  last(inboxId) {
    return axios.get(`${this.url}/${inboxId}`);
  }

  run(inboxId) {
    return axios.post(`${this.url}/${inboxId}/run`);
  }

  // Suscribe nuestra app a la WABA (sin cambiar la URL en bandejas dadas de alta a mano).
  subscribe(inboxId) {
    return axios.post(`${this.url}/${inboxId}/subscribe`);
  }
}

export default new WhatsappHealthAPI();
