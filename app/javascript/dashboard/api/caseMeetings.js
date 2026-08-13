/* global axios */
// @tickets_cases F2 — Reuniones (y series) de un ticket
import ApiClient from './ApiClient';

class CaseMeetingsAPI extends ApiClient {
  constructor() {
    super('case_tickets', { accountScoped: true });
  }

  getAll(ticketId) {
    return axios.get(`${this.url}/${ticketId}/meetings`);
  }

  createMeeting(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/meetings`, {
      case_meeting: data,
    });
  }

  updateMeeting(ticketId, id, data) {
    return axios.patch(`${this.url}/${ticketId}/meetings/${id}`, {
      case_meeting: data,
    });
  }

  deleteMeeting(ticketId, id) {
    return axios.delete(`${this.url}/${ticketId}/meetings/${id}`);
  }

  // Marcar realizada / no asistió: el quién y el cuándo los deriva el backend.
  hold(ticketId, id, status) {
    return axios.patch(`${this.url}/${ticketId}/meetings/${id}/hold`, {
      status,
    });
  }

  // F4 — serie de reuniones: crea el maestro y sus ocurrencias de una vez.
  createSeries(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/meeting-series`, {
      case_meeting_series: data,
    });
  }

  // Trunca la serie conservando lo realizado hasta `truncateAt` (un solo aviso).
  truncateSeries(ticketId, id, truncateAt) {
    return axios.patch(`${this.url}/${ticketId}/meeting-series/${id}`, {
      truncate_at: truncateAt,
    });
  }

  // Reintentar el espejo con Google tras un fallo (o tras conectar Calendar).
  resync(ticketId, id) {
    return axios.post(`${this.url}/${ticketId}/meetings/${id}/resync`);
  }

  // scope: 'one' (esta reunión) | 'all' (toda la serie).
  cancel(ticketId, id, scope = 'one') {
    return axios.patch(`${this.url}/${ticketId}/meetings/${id}/cancel`, {
      scope,
    });
  }
}

export default new CaseMeetingsAPI();
