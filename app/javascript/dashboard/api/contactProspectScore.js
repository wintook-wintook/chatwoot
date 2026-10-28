/* global axios */
// prospeccion P4 (D19): la puntuación del contacto en su campaña de Prospección más reciente
// (Contacts::ProspectScoresController).
import ApiClient from './ApiClient';

class ContactProspectScoreAPI extends ApiClient {
  constructor() {
    super('contacts', { accountScoped: true });
  }

  show(contactId) {
    return axios.get(`${this.url}/${contactId}/prospect_score`);
  }
}

export default new ContactProspectScoreAPI();
