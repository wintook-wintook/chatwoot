/* global axios */
// Responsable fijo del contacto (Contacts::OwnersController).
import ApiClient from './ApiClient';

class ContactOwnerAPI extends ApiClient {
  constructor() {
    super('contacts', { accountScoped: true });
  }

  show(contactId) {
    return axios.get(`${this.url}/${contactId}/owner`);
  }

  change(contactId, ownerId) {
    return axios.patch(`${this.url}/${contactId}/owner`, {
      owner_id: ownerId || '',
    });
  }
}

export default new ContactOwnerAPI();
