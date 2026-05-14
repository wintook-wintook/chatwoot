// ================================================================================
// proyecto@import_seguimiento
// ================================================================================
// API Client: ContactTrackingImportsAPI
// Descripción: Sube un archivo Excel/CSV para importar contactos a contact_trackings
// Nota: usa el axios global (window.axios) que ya lleva los headers de autenticación
//       de Chatwoot (user_token, account_id, etc.) configurados por los interceptores.
// ================================================================================

/* global axios */
import ApiClient from './ApiClient';

class ContactTrackingImportsAPI extends ApiClient {
  constructor() {
    super('contact_tracking_imports', { accountScoped: true });
  }

  importFile(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(this.url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }
}

export default new ContactTrackingImportsAPI();
