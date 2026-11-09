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

  get(id) {
    return axios.get(`${this.url}/${id}/ficha`);
  }

  // extra: { keyword_actions } (Reglas)
  save(id, items, extra = {}) {
    return axios.patch(`${this.url}/${id}/ficha`, { items, ...extra });
  }

  apply(id, { add = [], remove = [] }) {
    return axios.post(`${this.url}/${id}/ficha/apply`, { add, remove });
  }
}

export default new FichaAgenteAPI();
