/* global axios */

import ApiClient from './ApiClient';

// proyecto@respuestas_predefinidas R3: las categorías de las respuestas predefinidas.
class CannedResponseCategory extends ApiClient {
  constructor() {
    super('canned_response_categories', { accountScoped: true });
  }

  // Sugeridas por el principio de los nombres (D3).
  suggestions() {
    return axios.get(`${this.url}/suggestions`);
  }

  // Crear una con sus predefinidas (aceptar una sugerencia).
  createWith(name, cannedIds) {
    return axios.post(this.url, {
      canned_response_category: { name },
      canned_ids: cannedIds,
    });
  }
}

export default new CannedResponseCategory();
