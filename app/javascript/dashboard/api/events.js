/* global axios */
// Plan-Eventos E1 — eventos y su lista de contactos con estado.
import ApiClient from './ApiClient';

class EventsAPI extends ApiClient {
  constructor() {
    super('events', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  find(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(data) {
    return axios.post(this.url, { event: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { event: data });
  }

  remove(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  close(id) {
    return axios.post(`${this.url}/${id}/close`);
  }

  reopen(id) {
    return axios.post(`${this.url}/${id}/reopen`);
  }

  // { attendees, counts }
  attendees(id, params = {}) {
    return axios.get(`${this.url}/${id}/attendees`, { params });
  }

  addAttendees(id, contactIds, status = 'invited') {
    return axios.post(`${this.url}/${id}/add_attendees`, {
      contact_ids: contactIds,
      status,
    });
  }

  // Plan-Eventos E2 — todos los contactos de un segmento guardado.
  addSegment(id, segmentId, status = 'invited') {
    return axios.post(`${this.url}/${id}/add_segment`, {
      segment_id: segmentId,
      status,
    });
  }

  updateAttendee(id, attendeeId, status) {
    return axios.post(`${this.url}/${id}/update_attendee`, {
      attendee_id: attendeeId,
      status,
    });
  }

  removeAttendee(id, attendeeId) {
    return axios.post(`${this.url}/${id}/remove_attendee`, {
      attendee_id: attendeeId,
    });
  }

  importCsv(id, file) {
    const data = new FormData();
    data.append('file', file);
    return axios.post(`${this.url}/${id}/import`, data);
  }

  template() {
    return axios.get(`${this.url}/template`, { responseType: 'blob' });
  }

  forContact(contactId) {
    return axios.get(`${this.url}/for_contact`, {
      params: { contact_id: contactId },
    });
  }
}

export default new EventsAPI();
