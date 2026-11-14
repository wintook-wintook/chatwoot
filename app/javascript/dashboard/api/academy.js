/* global axios */
// Academia Kontrolya — «Mi capacitación» (Inicio): módulos, ejercicios y Cliente de práctica.
// El servidor (Academy::Board) revisa con los datos de verdad si ya hizo cada ejercicio.
import ApiClient from './ApiClient';

class AcademyAPI extends ApiClient {
  constructor() {
    super('academy', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  // «Leer» (lección) o «Hazlo» (ejercicio: desde aquí cuenta lo que haga).
  start(moduleKey, stepKey) {
    return axios.post(`${this.url}/steps/${moduleKey}/${stepKey}/start`);
  }

  // «Revisar» → { step, found, message }
  check(moduleKey, stepKey) {
    return axios.post(`${this.url}/steps/${moduleKey}/${stepKey}/check`);
  }

  // «Así me sirve» en un paso de configuración (undo: deshacerlo).
  confirm(moduleKey, stepKey, undo = false) {
    return axios.post(`${this.url}/steps/${moduleKey}/${stepKey}/confirm`, {
      undo,
    });
  }

  guide(key) {
    return axios.get(`${this.url}/guides/${key}`);
  }

  createPractice() {
    return axios.post(`${this.url}/practice`);
  }

  deletePractice() {
    return axios.delete(`${this.url}/practice`);
  }
}

export default new AcademyAPI();
