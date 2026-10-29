/* global axios */
// Página del contacto › Resumen (Contacts::SummariesController).
import ApiClient from './ApiClient';

class ContactSummaryAPI extends ApiClient {
  constructor() {
    super('contacts', { accountScoped: true });
  }

  show(contactId) {
    return axios.get(`${this.url}/${contactId}/summary`);
  }
}

export default new ContactSummaryAPI();
