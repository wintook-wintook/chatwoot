/* global axios */
import ApiClient from '../ApiClient';

class TiktokClient extends ApiClient {
  constructor() {
    super('tiktok', { accountScoped: true });
  }

  generateAuthorization() {
    return axios.post(`${this.url}/authorization`);
  }
}

export default new TiktokClient();
