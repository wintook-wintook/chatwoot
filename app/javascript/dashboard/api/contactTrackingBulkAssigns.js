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

// El cuerpo de crear y de modificar (por lote).
const campaignBody = ({
  payload,
  campaignName,
  templateId,
  scheduledFor,
  excludedContactIds = [],
  skipActive = true,
  window = {}, // proyecto@automatizacion_campanas: ends_at, entry_delay_minutes, respect_working_hours
  audienceSource = null, // { type: 'segment', segment_id } | { type: 'label', label }
}) => ({
  payload,
  campaign_name: campaignName,
  template_id: templateId,
  scheduled_for: scheduledFor,
  excluded_contact_ids: excludedContactIds,
  skip_active: skipActive,
  audience_source: audienceSource,
  ...window,
});

class ContactTrackingBulkAssignsAPI extends ApiClient {
  constructor() {
    super('contact_tracking_bulk_assigns', { accountScoped: true });
  }

  // launch=false → la campaña queda Guardada, sin inscribir a nadie.
  create({ launch = true, ...campaign }) {
    return axios.post(this.url, { ...campaignBody(campaign), launch });
  }

  // Modifica una campaña Guardada como por lote (sigue Guardada).
  update(id, campaign) {
    return axios.patch(`${this.url}/${id}`, campaignBody(campaign));
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
