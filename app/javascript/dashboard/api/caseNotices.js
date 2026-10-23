// ================================================================================
// @tickets_cases — «Tienes avisos importantes» de Mi día
// ================================================================================
// Avisos sin leer del agente con su peso. «Enterado» marca el aviso como leído con
// la misma API de la campanita (PATCH /notifications/:id).
// ================================================================================

import ApiClient from './ApiClient';

/* global axios */

class CaseNoticesAPI extends ApiClient {
  constructor() {
    super('case_notices', { accountScoped: true });
  }

  markRead(id) {
    return axios.patch(
      this.url.replace(/case_notices$/, `notifications/${id}`)
    );
  }
}

export default new CaseNoticesAPI();
