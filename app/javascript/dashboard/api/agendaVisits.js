/* global axios */
// Visitas sin orden de trabajo: Voy en camino, Llegué y el reporte de llegadas.
import ApiClient from './ApiClient';

class AgendaVisitsAPI extends ApiClient {
  constructor() {
    super('agenda_visits', { accountScoped: true });
  }

  onMyWay(id, etaMinutes) {
    return axios.post(`${this.url}/${id}/on_my_way`, {
      eta_minutes: etaMinutes,
    });
  }

  arrive(id, location = {}) {
    return axios.post(`${this.url}/${id}/arrive`, location);
  }

  arrivals(params = {}) {
    return axios.get(`${this.url}/arrivals`, { params });
  }
}

export default new AgendaVisitsAPI();
