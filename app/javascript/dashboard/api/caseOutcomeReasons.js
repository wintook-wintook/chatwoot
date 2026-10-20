// @tickets_cases — Plan-Clase-Comercial F4: catálogo de motivos de cierre de oportunidades.
import ApiClient from './ApiClient';

class CaseOutcomeReasonsAPI extends ApiClient {
  constructor() {
    super('case_outcome_reasons', { accountScoped: true });
  }
}

export default new CaseOutcomeReasonsAPI();
