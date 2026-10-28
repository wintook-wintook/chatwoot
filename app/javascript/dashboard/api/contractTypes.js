/* global axios */
// Plan-Contratos R1 — tipos de contrato de la empresa.
import ApiClient from './ApiClient';

class ContractTypesAPI extends ApiClient {
  constructor() {
    super('contract_types', { accountScoped: true });
  }

  list(activeOnly = false) {
    return axios.get(this.url, { params: activeOnly ? { active: true } : {} });
  }

  create(data) {
    return axios.post(this.url, { contract_type: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { contract_type: data });
  }
}

export default new ContractTypesAPI();
