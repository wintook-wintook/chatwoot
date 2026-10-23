// @tickets_cases
import ApiClient from './ApiClient';

/* global axios */

class CaseTypesAPI extends ApiClient {
  constructor() {
    super('case_types', { accountScoped: true });
  }

  getAll() {
    return axios.get(this.url);
  }

  // Cambiar de clase: con casos crea el tipo en la otra clase y retira este (sus
  // casos se quedan tal cual); sin casos cambia directo.
  changeClass(id, caseClass) {
    return axios.post(`${this.url}/${id}/change_class`, {
      case_class: caseClass,
    });
  }
}

export default new CaseTypesAPI();
