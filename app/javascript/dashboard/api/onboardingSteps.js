/* global axios */
// «Primeros pasos» (Inicio): qué ya hizo el usuario, revisado en vivo en el servidor.
import ApiClient from './ApiClient';

class OnboardingStepsAPI extends ApiClient {
  constructor() {
    super('onboarding_steps', { accountScoped: true });
  }

  list() {
    return axios.get(this.url);
  }
}

export default new OnboardingStepsAPI();
