// @campanas_vendedor
// ================================================================================
// API Client: trackingCampaigns
// Descripción: Listado de campañas (corridas de asignación masiva) con stats,
//              para el Dashboard de Seguimientos. Hereda get()/show() de ApiClient.
// ================================================================================

import ApiClient from './ApiClient';

class TrackingCampaignsAPI extends ApiClient {
  constructor() {
    super('tracking_campaigns', { accountScoped: true });
  }
}

export default new TrackingCampaignsAPI();
