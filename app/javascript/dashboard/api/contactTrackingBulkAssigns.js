// proyecto@bulk_tracking_assign
// ================================================================================
// proyecto@bulk_tracking_assign
// ================================================================================
// API Client: ContactTrackingBulkAssignsAPI
// Descripción: Asigna una TrackingTemplate a un conjunto de contactos resuelto
//              por filtro (mismo formato que /contacts/filter).
// ================================================================================

/* global axios */
import ApiClient from './ApiClient';

class ContactTrackingBulkAssignsAPI extends ApiClient {
  constructor() {
    super('contact_tracking_bulk_assigns', { accountScoped: true });
  }

  create({
    payload,
    campaignName,
    templateId,
    scheduledFor,
    excludedContactIds = [],
    skipActive = true,
  }) {
    return axios.post(this.url, {
      payload,
      campaign_name: campaignName,
      template_id: templateId,
      scheduled_for: scheduledFor,
      excluded_contact_ids: excludedContactIds,
      skip_active: skipActive,
    });
  }

  // @campanas_vendedor — dry-run: clasifica la audiencia en buckets (sin crear nada).
  preview({ payload, templateId, skipActive = true, excludedContactIds = [] }) {
    return axios.post(`${this.url}/preview`, {
      payload,
      template_id: templateId,
      skip_active: skipActive,
      excluded_contact_ids: excludedContactIds,
    });
  }
}

export default new ContactTrackingBulkAssignsAPI();
