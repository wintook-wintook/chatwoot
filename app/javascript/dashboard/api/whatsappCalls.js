/* global axios */
// diag/llamadas_whatsapp (F5) — contestar, rechazar, colgar y llamar (F3); grabación (F7).
import ApiClient from './ApiClient';

class WhatsappCallsAPI extends ApiClient {
  constructor() {
    super('whatsapp_calls', { accountScoped: true });
  }

  accept(callId, sdpAnswer) {
    return axios.post(`${this.url}/${callId}/accept`, {
      sdp_answer: sdpAnswer,
    });
  }

  reject(callId) {
    return axios.post(`${this.url}/${callId}/reject`);
  }

  terminate(callId) {
    return axios.post(`${this.url}/${callId}/terminate`);
  }

  // F7: la grabación al colgar (multipart).
  uploadRecording(callId, archivo, nombre) {
    const formData = new FormData();
    formData.append('recording', archivo, nombre);
    return axios.post(`${this.url}/${callId}/upload_recording`, formData);
  }

  initiate(conversationId, sdpOffer) {
    return axios.post(`${this.url}/initiate`, {
      conversation_id: conversationId,
      sdp_offer: sdpOffer,
    });
  }
}

export default new WhatsappCallsAPI();
