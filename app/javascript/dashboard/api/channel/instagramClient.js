/* global axios */
import ApiClient from '../ApiClient';

class InstagramClient extends ApiClient {
  constructor() {
    super('instagram', { accountScoped: true });
  }

  generateAuthorization() {
    return axios.post(`${this.url}/authorization`);
  }
}

export default new InstagramClient();
