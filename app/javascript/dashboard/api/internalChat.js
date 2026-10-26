/* global axios */
// feat/chat_interno (F3) — API del chat interno entre agentes.
// Ver app/controllers/api/v1/accounts/internal_chat/*_controller.rb
import ApiClient from './ApiClient';

class InternalChatAPI extends ApiClient {
  constructor() {
    super('internal_chat/rooms', { accountScoped: true });
  }

  getRooms() {
    return axios.get(this.url);
  }

  openDirect(userId) {
    return axios.post(this.url, { kind: 'direct', user_id: userId });
  }

  createGroup(name, userIds) {
    return axios.post(this.url, { kind: 'group', name, user_ids: userIds });
  }

  rename(roomId, name) {
    return axios.patch(`${this.url}/${roomId}`, { name });
  }

  markRead(roomId) {
    return axios.post(`${this.url}/${roomId}/read`);
  }

  getMessages(roomId, before) {
    return axios.get(`${this.url}/${roomId}/messages`, {
      params: before ? { before } : {},
    });
  }

  sendMessage(roomId, content) {
    return axios.post(`${this.url}/${roomId}/messages`, { content });
  }

  addMembers(roomId, userIds) {
    return axios.post(`${this.url}/${roomId}/members`, { user_ids: userIds });
  }

  removeMember(roomId, userId) {
    return axios.delete(`${this.url}/${roomId}/members/${userId}`);
  }
}

export default new InternalChatAPI();
