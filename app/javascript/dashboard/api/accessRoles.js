/* global axios */
// Plan-Roles-Permisos P3 — Ajustes › Roles.
import ApiClient from './ApiClient';

class AccessRolesAPI extends ApiClient {
  constructor() {
    super('access_roles', { accountScoped: true });
  }

  restore(id) {
    return axios.post(`${this.url}/${id}/restore`);
  }
}

export default new AccessRolesAPI();
