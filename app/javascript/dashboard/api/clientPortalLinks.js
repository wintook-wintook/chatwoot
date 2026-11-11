/* global axios */
// Portal del cliente — el enlace de una organización (o de un contacto sin organización).
// `owner`: { organization_id } o { contact_id }.
import ApiClient from './ApiClient';

class ClientPortalLinksAPI extends ApiClient {
  constructor() {
    super('client_portal_link', { accountScoped: true });
  }

  show(owner) {
    return axios.get(this.url, { params: owner });
  }

  create(owner) {
    return axios.post(this.url, owner);
  }

  renew(owner) {
    return axios.post(`${this.url}/renew`, owner);
  }

  disable(owner) {
    return axios.post(`${this.url}/disable`, owner);
  }
}

export default new ClientPortalLinksAPI();
