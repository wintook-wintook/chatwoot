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
}

export default new AssistantAPI();
