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

  // proyecto@automatizacion_campanas — reanuda una campaña pausada por error de Meta.
  resume(id) {
    return axios.post(`${this.url}/${id}/resume`);
  }

  // prospeccion V6: entregar un prospecto interesado a un vendedor
  handOff(id, trackingId) {
    return axios.post(`${this.url}/${id}/hand_off`, {
      tracking_id: trackingId,
    });
  }
}

export default new TrackingCampaignsAPI();
