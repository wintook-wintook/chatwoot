/* global axios */
// Buscar en todo (la lupa de la barra de arriba): contactos, organizaciones y casos.
import ApiClient from './ApiClient';

class GlobalSearchAPI extends ApiClient {
  constructor() {
    super('global_search', { accountScoped: true });
  }

  // `type` + `page` para «ver más» de un grupo (contacts | organizations | cases).
  search(q, { type, page } = {}) {
    return axios.get(this.url, { params: { q, type, page } });
  }
}

export default new GlobalSearchAPI();
