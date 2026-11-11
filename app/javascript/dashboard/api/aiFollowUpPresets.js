/* global axios */
// Plantillas de seguimiento: la receta de un Seguimiento IA para volver a usarla al delegar.
import ApiClient from './ApiClient';

class AiFollowUpPresetsAPI extends ApiClient {
  constructor() {
    super('ai_follow_up_presets', { accountScoped: true });
  }

  list() {
    return axios.get(this.url);
  }
}

export default new AiFollowUpPresetsAPI();
