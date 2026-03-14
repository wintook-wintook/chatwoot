// ============================================================
// proyecto@contacts_notes
// ============================================================
// Archivo: contactNotes.js (API)
// Descripción: API client para notas de contacto.
//              Modificado para agregar soporte de actualización (update).
// ============================================================
import ApiClient from './ApiClient';

class ContactNotes extends ApiClient {
  constructor() {
    super('notes', { accountScoped: true });
    this.contactId = null;
  }

  get url() {
    return `${this.baseUrl()}/contacts/${this.contactId}/notes`;
  }

  get(contactId) {
    this.contactId = contactId;
    return super.get();
  }

  create(contactId, content) {
    this.contactId = contactId;
    return super.create({ content });
  }

  // ============================================================
  // proyecto@contacts_notes - NUEVO: Actualizar nota existente
  // ============================================================
  update(contactId, noteId, content, isForIa = undefined) {
    this.contactId = contactId;
    const payload = { content };
    if (isForIa !== undefined) payload.is_for_ia = isForIa;
    return super.update(noteId, payload);
  }

  toggleSpecial(contactId, noteId, isForIa) {
    this.contactId = contactId;
    return super.update(noteId, { is_for_ia: isForIa });
  }

  delete(contactId, id) {
    this.contactId = contactId;
    return super.delete(id);
  }
}

export default new ContactNotes();
