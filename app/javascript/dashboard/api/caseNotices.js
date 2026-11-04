// ================================================================================
// @tickets_cases — «Tienes avisos importantes» de Mi día
// ================================================================================
// Avisos sin leer del agente con su peso, uno por conversación o caso. «Enterado»
// los marca leídos con la API de la campanita: read_all por actor, o PATCH
// /notifications/:id para los demás (calendario).
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

  // Todos los sin leer de esa conversación o caso, como la campanita. Ojo: sin un
  // actor válido read_all marca TODOS los avisos; solo se llama con Conversation o
  // CaseTicket (ver MyDayNotices.vue).
  markActorRead(actorType, actorId) {
    return axios.post(
      this.url.replace(/case_notices$/, 'notifications/read_all'),
      { primary_actor_type: actorType, primary_actor_id: actorId }
    );
  }
}

export default new CaseNoticesAPI();
