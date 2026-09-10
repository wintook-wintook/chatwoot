// proyecto@asistente_agentes_ia
// ================================================================================
// API Client: assistant
// Descripción: Endpoints del Asistente de Agentes IA. Cuelgan de contact_trackings
//              y no de un /assistant a nivel cuenta: este asistente es del motor de
//              Seguimientos, y Chatwoot ya tiene el suyo propio (Captain).
// ================================================================================

/* global axios */
import ApiClient from './ApiClient';

class AssistantAPI extends ApiClient {
  constructor() {
    super('contact_trackings/assistant', { accountScoped: true });
  }

  // Lo que la cuenta tiene para armar un Entrenamiento: fuentes con su directiva
  // exacta, grupos, tipos de caso, etiquetas y frases reales de clientes.
  getInventory(inboxId) {
    const params = inboxId ? { inbox_id: inboxId } : {};
    return axios.get(`${this.url}/inventory`, { params });
  }

  // Un turno de entrevista. Es el único que gasta tokens.
  // oneShot: sin entrevista, redacta de una. Lo usa el botón "generar" de la ficha
  // del Agente IA, donde no hay conversación en la que preguntar.
  interview(messages, inboxId, { oneShot = false, sessionId = null } = {}) {
    return axios.post(`${this.url}/interview`, {
      messages,
      inbox_id: inboxId,
      one_shot: oneShot,
      session_id: sessionId,
    });
  }

  // La conversación a medias de quien pregunta, si la hay. Una entrevista dura
  // 30–45 minutos: cerrar la pestaña no debería tirarla.
  getSession() {
    return axios.get(`${this.url}/session`);
  }

  // Las conversaciones de quien pregunta: un Entrenamiento bueno rara vez sale de
  // una sentada, y sin listado cada una era un callejón sin salida.
  getSessions() {
    return axios.get(`${this.url}/sessions`);
  }

  openSession(id) {
    return axios.get(`${this.url}/sessions/${id}`);
  }

  discardSession(id) {
    return axios.delete(`${this.url}/sessions/${id}`);
  }

  // Solo el comprobador, sin IA: por eso puede correr en cada tecleo del panel.
  validate(draft) {
    return axios.post(`${this.url}/validate`, { draft });
  }

  // Pasa todos los Agentes IA de la cuenta por el comprobador. Sin IA: son parseos.
  audit() {
    return axios.get(`${this.url}/audit`);
  }

  // mode: 'create' crea un Agente IA nuevo; 'replace' pisa el de uno existente.
  save({
    draft,
    mode,
    name,
    objective,
    aiContext,
    inboxId,
    templateId,
    sessionId,
  }) {
    return axios.post(`${this.url}/save`, {
      draft,
      mode,
      name,
      objective,
      ai_context: aiContext,
      inbox_id: inboxId,
      template_id: templateId,
      session_id: sessionId,
    });
  }
}

export default new AssistantAPI();
