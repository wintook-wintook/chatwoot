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

  // feat/plantillas_whatsapp_mejoras F6: sube el archivo de muestra del encabezado. Devuelve
  // { signed_id, filename, url }; el signed_id va como header_sample al crear o editar.
  uploadHeaderSample(headerType, file) {
    const data = new FormData();
    data.append('header_type', headerType);
    data.append('file', file);
    return axios.post(`${this.url}/header_samples`, data);
  }
}

export default new WhatsappTemplatesAPI();
