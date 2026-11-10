/* global axios */
// feat/ficha_agente_ia — la ficha del Agente IA (docs/ficha_agente_ia_plan.md)
//   catalog(inboxId)          tarjetas para marcar (agente nuevo)
//   preview(payload)          ofertas + Entrenamiento generado + comprobador
//   create(payload)           crea el agente desde la ficha (sin IA)
//   get(id) / save(id, items) la ficha de un agente y sus cambios contra el prompt
//   apply(id, { add, remove }) aplica cambios al prompt (con el OK de la persona)
import ApiClient from './ApiClient';

class FichaAgenteAPI extends ApiClient {
  constructor() {
    super('tracking_templates', { accountScoped: true });
  }

  catalog(inboxId) {
    return axios.get(`${this.url}/ficha_catalog`, {
      params: inboxId ? { inbox_id: inboxId } : {},
    });
  }

  preview(payload) {
    return axios.post(`${this.url}/ficha_preview`, payload);
  }

  create(payload) {
    return axios.post(`${this.url}/ficha_create`, payload);
  }

  // ✨ objetivo y contexto propuestos con IA (una llamada a OpenAI)
  suggest(payload) {
    return axios.post(`${this.url}/ficha_suggest`, payload);
  }

  // Probar antes de crear (corre en segundo plano) y su avance/resultado.
  test(payload) {
    return axios.post(`${this.url}/ficha_test`, payload);
  }

  testResult(turnId) {
    return axios.get(`${this.url}/ficha_test/${turnId}`);
  }

  // Crea la automatización que se lo asigna a las conversaciones de su canal.
  activate(id) {
    return axios.post(`${this.url}/${id}/ficha/activate`);
  }

  // Columnas y primeras filas de una hoja (para decir qué hacer con ella).
  sheet(sourceId) {
    return axios.get(`${this.url}/ficha_sheet/${sourceId}`);
  }

  get(id) {
    return axios.get(`${this.url}/${id}/ficha`);
  }

  // extra: { keyword_actions } (Reglas)
  save(id, items, extra = {}) {
    return axios.patch(`${this.url}/${id}/ficha`, { items, ...extra });
  }

  // phrases: { ruta: [frases] } — se suman a la descripción de esa ruta.
  apply(id, { add = [], remove = [], phrases = {} }) {
    return axios.post(`${this.url}/${id}/ficha/apply`, {
      add,
      remove,
      phrases,
    });
  }

  // Probar un agente que ya existe (su Entrenamiento guardado).
  testExisting(id, turnId) {
    return axios.post(`${this.url}/${id}/ficha/test`, { turn_id: turnId });
  }
}

export default new FichaAgenteAPI();
