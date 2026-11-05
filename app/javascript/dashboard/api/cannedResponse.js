/* global axios */

import ApiClient from './ApiClient';

class CannedResponse extends ApiClient {
  constructor() {
    super('canned_responses', { accountScoped: true });
  }

  get({ searchKey }) {
    const url = searchKey ? `${this.url}?search=${searchKey}` : this.url;
    return axios.get(url);
  }

  // proyecto@respuestas_predefinidas R1: meterla a la fuente de datos (una, o hasta 20).
  vectorize(id) {
    return axios.post(`${this.url}/${id}/vectorize`);
  }

  vectorizeMany(ids) {
    return axios.post(`${this.url}/vectorize`, { ids });
  }
}

export default new CannedResponse();
