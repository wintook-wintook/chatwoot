/* global axios */
// feat/apariencia B1 — logo y color de la empresa.
// Ver app/controllers/api/v1/accounts/brands_controller.rb
import ApiClient from './ApiClient';

class AccountBrandAPI extends ApiClient {
  constructor() {
    super('brand', { accountScoped: true });
  }

  // FormData con `tint` y/o `logo` (archivo).
  update(data) {
    return axios.patch(this.url, data);
  }

  removeLogo() {
    return axios.delete(this.url);
  }
}

export default new AccountBrandAPI();
