// @campanas_vendedor
// ================================================================================
// API Client: trackingCampaigns
// Descripción: Listado de campañas (corridas de asignación masiva) con stats,
//              para el Dashboard de Seguimientos. Hereda get()/show() de ApiClient.
// ================================================================================

/* global axios */
import ApiClient from './ApiClient';

class TrackingCampaignsAPI extends ApiClient {
  constructor() {
    super('tracking_campaigns', { accountScoped: true });
  }

  // proyecto@automatizacion_campanas — la lista liviana (sin stats) para selectores, como
  // la acción de automatización "Agregar a campaña".
  getOptions() {
    return axios.get(this.url, { params: { lite: true } });
  }

  // proyecto@automatizacion_campanas — inscritos y omitidos de una campaña (paginado).
  getEntries(id, page = 1) {
    return axios.get(`${this.url}/${id}/entries`, { params: { page } });
  }

  // proyecto@automatizacion_campanas — pone en curso una campaña Guardada.
  launch(id) {
    return axios.post(`${this.url}/${id}/launch`);
  }

  // Botón «Pausar campaña»: pausa a mano una Programada o En curso.
  pause(id) {
    return axios.post(`${this.url}/${id}/pause`);
  }

  // proyecto@automatizacion_campanas — reanuda una campaña pausada (por error de Meta o a mano).
  resume(id) {
    return axios.post(`${this.url}/${id}/resume`);
  }

  // prospeccion V6: entregar un prospecto interesado a un vendedor
  handOff(id, trackingId) {
    return axios.post(`${this.url}/${id}/hand_off`, {
      tracking_id: trackingId,
    });
  }

  // prospeccion P4: pesos y reglas de la puntuación ({ scoring } · { copy_from_campaign_id } · { reset: true })
  updateScoring(id, body) {
    return axios.patch(`${this.url}/${id}/scoring`, body);
  }

  // prospeccion P3: quedarse con el asunto A o B de la prueba
  chooseSubject(id, variant) {
    return axios.post(`${this.url}/${id}/subject_winner`, { variant });
  }

  // prospeccion P2: tablero/columna de Oportunidades, plazo y escalar
  updateHandoffSettings(id, settings) {
    return axios.patch(`${this.url}/${id}/handoff_settings`, settings);
  }
}

export default new TrackingCampaignsAPI();
