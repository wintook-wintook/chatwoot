// ================================================================================
// @tickets_cases — «Mi resumen» (página Inicio)
// ================================================================================
// Conversaciones, casos y números de la semana del agente. Mi día y los avisos
// tienen su propia API (case_tasks?mode=my_day y case_notices).
// ================================================================================

import ApiClient from './ApiClient';

class MySummaryAPI extends ApiClient {
  constructor() {
    super('my_summary', { accountScoped: true });
  }
}

export default new MySummaryAPI();
