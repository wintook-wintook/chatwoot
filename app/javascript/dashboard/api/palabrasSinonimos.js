/* global axios */

import ApiClient from './ApiClient';

// Sinónimos nativos (esquema legacy wintook), guardado "como Chatwoot".
// Reemplaza los fetch al servicio externo WINTOOK_BOT.
class PalabrasSinonimos extends ApiClient {
  constructor() {
    super('palabras_sinonimos', { accountScoped: true });
  }

  raices({ search = '', page = 1 } = {}) {
    return axios.get(this.url, { params: { tipo: 'raiz', search, page } });
  }

  raicesSelect() {
    return axios.get(this.url, { params: { tipo: 'raiz', select: 1 } });
  }

  sinonimos({ raizId = '', search = '', page = 1 } = {}) {
    return axios.get(this.url, {
      params: { tipo: 'sinonimo', raiz_id: raizId, search, page },
    });
  }

  crearRaiz({ palabra, sinonimoSemanticoId = null }) {
    return axios.post(this.url, {
      tipo: 'raiz',
      palabra,
      sinonimo_semantico_id: sinonimoSemanticoId,
    });
  }

  crearSinonimo({ palabra, palabraSinonimoId }) {
    return axios.post(this.url, {
      tipo: 'sinonimo',
      palabra,
      palabra_sinonimo_id: palabraSinonimoId,
    });
  }

  actualizar(id, payload) {
    return axios.patch(`${this.url}/${id}`, payload);
  }

  eliminar(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new PalabrasSinonimos();
