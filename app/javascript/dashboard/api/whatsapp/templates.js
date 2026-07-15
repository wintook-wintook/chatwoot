// @waba_templates — API de gestión de plantillas de WhatsApp (account-scoped, admin).
import ApiClient from '../ApiClient';

/* global axios */

class WhatsappTemplatesAPI extends ApiClient {
  constructor() {
    super('whatsapp/templates', { accountScoped: true });
  }

  get(inboxId) {
    return axios.get(this.url, { params: { inbox_id: inboxId } });
  }

  create(inboxId, template) {
    return axios.post(this.url, {
      inbox_id: inboxId,
      whatsapp_template: template,
    });
  }

  update(id, template) {
    return axios.patch(`${this.url}/${id}`, { whatsapp_template: template });
  }

  sync(inboxId) {
    return axios.post(`${this.url}/sync`, { inbox_id: inboxId });
  }

  // Importa al instante lo que los canales ya tienen en cache (sin llamar a Meta).
  import() {
    return axios.post(`${this.url}/import`);
  }
}

export default new WhatsappTemplatesAPI();
