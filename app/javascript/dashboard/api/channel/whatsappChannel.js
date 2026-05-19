/**
 * proyecto@waba_chatwoot
 * WhatsappChannel API Client
 *
 * Cliente para el endpoint de WhatsApp Embedded Signup.
 * Envía al backend el código OAuth y los datos del negocio
 * obtenidos del popup de Meta para que el servidor cree el inbox.
 *
 * Endpoint:
 *   POST /api/v1/accounts/:account_id/whatsapp/authorization
 *
 * Usado por: store/modules/inboxes.js → createWhatsAppEmbeddedSignup
 */
/* global axios */
import ApiClient from '../ApiClient';

class WhatsappChannel extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  createEmbeddedSignup(params) {
    return axios.post(`${this.baseUrl()}/whatsapp/authorization`, params);
  }
}

export default new WhatsappChannel();
