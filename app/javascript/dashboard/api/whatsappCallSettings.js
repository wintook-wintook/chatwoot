/* global axios */
// diag/llamadas_whatsapp (F6) — la pestaña «Llamadas» de una bandeja.
import ApiClient from './ApiClient';

class WhatsappCallSettingsAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  show(inboxId) {
    return axios.get(`${this.url}/${inboxId}/whatsapp_call_settings`);
  }

  update(inboxId, settings) {
    return axios.patch(
      `${this.url}/${inboxId}/whatsapp_call_settings`,
      settings
    );
  }
}

export default new WhatsappCallSettingsAPI();
