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
  // `draft`: el Entrenamiento que está en pantalla, con lo editado a mano. Sin él
  // el asistente no puede modificar nada, solo reescribir de memoria.
  // `deliveredDraft`: lo último que entregó el asistente. La diferencia con
  // `draft` es lo editado a mano; "" = todavía no entregó nada.
  interview(
    messages,
    inboxId,
    {
      oneShot = false,
      sessionId = null,
      draft = null,
      deliveredDraft = null,
      building = null,
      turnId = null,
    } = {}
  ) {
    const body = {
      messages,
      inbox_id: inboxId,
      one_shot: oneShot,
      session_id: sessionId,
      draft,
    };
    // Solo si se sabe: sin la llave, el backend no busca ediciones a mano.
    if (deliveredDraft !== null) body.delivered_draft = deliveredDraft;
    // La entrevista sigue abierta. Sin la llave, el backend lo deduce de las marcas.
    if (building !== null) body.building = building;
    // Con él, el backend va dejando la etapa en curso para getProgress.
    if (turnId) body.turn_id = turnId;
    return axios.post(`${this.url}/interview`, body);
  }

  // Fase E: mensajes de prueba pasados por el clasificador real. Tarda (una
  // clasificación por mensaje): con turnId se puede consultar el avance.
  suggestedTests(draft, turnId = null, inboxId = null) {
    return axios.post(`${this.url}/suggested_tests`, {
      draft,
      turn_id: turnId,
      inbox_id: inboxId,
    });
  }

  // Fase E: hallazgos y una propuesta que nunca se aplica sola. Corre en segundo
  // plano (tarda más que el límite de la request): responde 202 y el resultado se
  // pide con getOptimizeResult(turnId) hasta que deja de ser 202.
  optimize(draft, turnId, inboxId = null) {
    return axios.post(`${this.url}/optimize`, {
      draft,
      turn_id: turnId,
      inbox_id: inboxId,
    });
  }

  getOptimizeResult(turnId) {
    return axios.get(`${this.url}/optimize/${turnId}`);
  }

  // Fase E: qué hace un fragmento del Entrenamiento.
  explain(draft, excerpt, inboxId = null) {
    return axios.post(`${this.url}/explain`, {
      draft,
      excerpt,
      inbox_id: inboxId,
    });
  }

  // El Objetivo o el Contexto con la redacción y la ortografía corregidas. No toca
  // ningún dato (ver Proofreader) y la pantalla siempre deja volver al original.
  proofread(text, kind, inboxId = null) {
    return axios.post(`${this.url}/proofread`, {
      text,
      kind,
      inbox_id: inboxId,
    });
  }

  // Lo que se dictó, en texto. Vuelve al cuadro de mensaje sin enviarse.
  transcribe(file) {
    const formData = new FormData();
    formData.append('audio', file, file.name || 'dictado.ogg');
    return axios.post(`${this.url}/transcribe`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  // El texto de una versión del Entrenamiento: las listas llegan sin él.
  getVersion(sessionId, number) {
    return axios.get(`${this.url}/sessions/${sessionId}/versions/${number}`);
  }

  // En qué etapa está un turno que todavía no terminó.
  getProgress(turnId) {
    return axios.get(`${this.url}/progress/${turnId}`);
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

  // Probar sin enviar nada: qué haría el motor con UNA pregunta. No escribe nada,
  // pero sí gasta (clasifica la rama y vectoriza la pregunta), así que va con
  // botón — a diferencia de validate, que corre al teclear.
  dryRun(draft, question, inboxId) {
    return axios.post(`${this.url}/dry_run`, {
      draft,
      question,
      inbox_id: inboxId,
    });
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
