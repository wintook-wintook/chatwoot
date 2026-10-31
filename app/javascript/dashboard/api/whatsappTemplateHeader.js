/* global axios */
// feat/plantillas_whatsapp_mejoras — el archivo del encabezado en el formulario de la
// conversación: el guardado en la plantilla, o uno que el agente sube para este envío.
import ApiClient from './ApiClient';

class WhatsappTemplateHeaderAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  show(inboxId, { name, language }) {
    return axios.get(`${this.url}/${inboxId}/whatsapp_template_header`, {
      params: { name, language },
    });
  }

  // Otro archivo, de la máquina del agente, para este envío.
  upload(inboxId, { mediaType, file }) {
    const formData = new FormData();
    formData.append('media_type', mediaType);
    formData.append('file', file);
    return axios.post(
      `${this.url}/${inboxId}/whatsapp_template_header`,
      formData
    );
  }
}

export default new WhatsappTemplateHeaderAPI();
