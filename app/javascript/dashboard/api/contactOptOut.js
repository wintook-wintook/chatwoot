/* global axios */
// prospeccion V4: «no contactar» del contacto (Contacts::OptOutsController).
import ApiClient from './ApiClient';

class ContactOptOutAPI extends ApiClient {
  constructor() {
    super('contacts', { accountScoped: true });
  }

  mark(contactId) {
    return axios.post(`${this.url}/${contactId}/opt_out`);
  }

  undo(contactId) {
    return axios.delete(`${this.url}/${contactId}/opt_out`);
  }
}

export default new ContactOptOutAPI();
