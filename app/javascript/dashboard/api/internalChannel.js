/* global axios */
// feat/chat_interno (plan v2) — la bandeja «Interno».
// Ver app/controllers/api/v1/accounts/internal_channels_controller.rb
import ApiClient from './ApiClient';

class InternalChannelAPI extends ApiClient {
  constructor() {
    super('internal_channel', { accountScoped: true });
  }

  // La deja lista (bandeja, # general, equipos) y da su id.
  ensure() {
    return axios.get(this.url);
  }

  // feat/chat_interno_pulido: { inbox_id, unread } — lo que el agente tiene sin leer.
  unread() {
    return axios.get(`${this.url}/unread`);
  }

  // El directo con ese agente (lo crea si no existe): { conversation_id, inbox_id }.
  openDirect(userId) {
    return axios.post(`${this.url}/directs`, { user_id: userId });
  }
}

export default new InternalChannelAPI();
