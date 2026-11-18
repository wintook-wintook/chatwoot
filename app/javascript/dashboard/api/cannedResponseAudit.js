/* global axios */

import ApiClient from './ApiClient';

// proyecto@auditoria_predefinidas — la pestaña «Auditoría» de Respuestas predefinidas.
class CannedResponseAudit extends ApiClient {
  constructor() {
    super('canned_response_audit', { accountScoped: true });
  }

  // status: 'open' (por omisión) | 'dismissed'
  show(status) {
    return axios.get(this.url, { params: { status } });
  }

  // «Auditar»: corre en segundo plano; regresa la corrida (status running).
  run() {
    return axios.post(this.url);
  }

  // 'dismissed' = descartar; 'open' = reabrir.
  setStatus(findingId, status) {
    return axios.patch(`${this.url}/findings/${findingId}`, { status });
  }

  // Duplicadas: conservar `keepId` y eliminar la otra.
  keep(findingId, keepId) {
    return axios.post(`${this.url}/findings/${findingId}/keep`, {
      keep_id: keepId,
    });
  }
}

export default new CannedResponseAudit();
