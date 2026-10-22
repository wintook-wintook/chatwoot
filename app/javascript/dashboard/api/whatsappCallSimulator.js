/* global axios */
// diag/llamadas_whatsapp (F4) — el «cliente simulado» (solo con la Meta simulada).
import ApiClient from './ApiClient';

class WhatsappCallSimulatorAPI extends ApiClient {
  constructor() {
    super('whatsapp_call_simulator', { accountScoped: true });
  }

  inboxes() {
    return axios.get(`${this.url}/inboxes`);
  }

  signals(inboxId, waId) {
    return axios.get(`${this.url}/signals`, {
      params: { inbox_id: inboxId, wa_id: waId },
    });
  }

  call({ inboxId, waId, name, sdpOffer }) {
    return axios.post(`${this.url}/call`, {
      inbox_id: inboxId,
      wa_id: waId,
      name,
      sdp_offer: sdpOffer,
    });
  }

  answer({ inboxId, callId, sdpAnswer }) {
    return axios.post(`${this.url}/answer`, {
      inbox_id: inboxId,
      call_id: callId,
      sdp_answer: sdpAnswer,
    });
  }

  hangup({ inboxId, callId, duration }) {
    return axios.post(`${this.url}/hangup`, {
      inbox_id: inboxId,
      call_id: callId,
      duration,
    });
  }

  permission({ inboxId, waId, wamid, accept }) {
    return axios.post(`${this.url}/permission`, {
      inbox_id: inboxId,
      wa_id: waId,
      wamid,
      accept,
    });
  }
}

export default new WhatsappCallSimulatorAPI();
