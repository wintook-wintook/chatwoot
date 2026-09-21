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
}

export default new TrackingCampaignsAPI();
