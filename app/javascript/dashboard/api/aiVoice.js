/* global axios */
// «Cómo habla tu empresa»: base común de Seguimiento IA y Agentes listos.
import ApiClient from './ApiClient';

class AiVoiceAPI extends ApiClient {
  constructor() {
    super('ai_voice', { accountScoped: true });
  }

  update(voice) {
    return axios.patch(this.url, { voice });
  }

  // Mensaje de ejemplo con lo del formulario (sin guardar ni mandar nada).
  preview(voice, kind) {
    return axios.post(`${this.url}/preview`, { voice, kind });
  }
}

export default new AiVoiceAPI();
