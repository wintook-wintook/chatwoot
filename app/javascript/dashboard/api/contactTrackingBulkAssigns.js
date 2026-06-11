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
    templateId,
    scheduledFor,
    excludedContactIds = [],
    skipActive = true,
  }) {
    return axios.post(this.url, {
      payload,
      template_id: templateId,
      scheduled_for: scheduledFor,
      excluded_contact_ids: excludedContactIds,
      skip_active: skipActive,
    });
  }
}

export default new ContactTrackingBulkAssignsAPI();
