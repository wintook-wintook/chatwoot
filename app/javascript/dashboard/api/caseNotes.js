// @tickets_cases — Notas internas de un ticket
import ApiClient from './ApiClient';

class CaseNotesAPI extends ApiClient {
  constructor() {
    super('case_tickets', { accountScoped: true });
  }

  getAll(ticketId) {
    return axios.get(`${this.url}/${ticketId}/notes`);
  }

  createNote(ticketId, data) {
    return axios.post(`${this.url}/${ticketId}/notes`, { case_note: data });
  }

  updateNote(ticketId, id, data) {
    return axios.patch(`${this.url}/${ticketId}/notes/${id}`, {
      case_note: data,
    });
  }

  deleteNote(ticketId, id) {
    return axios.delete(`${this.url}/${ticketId}/notes/${id}`);
  }
}

export default new CaseNotesAPI();
