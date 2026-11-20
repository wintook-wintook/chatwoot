/* global axios */
// Campaña con Vendedor IA (Motor 2.0): la pantalla nueva. Pausar y reanudar son los de trackingCampaigns.
import ApiClient from './ApiClient';

class Motor2CampaignsAPI extends ApiClient {
  constructor() {
    super('motor2_campaigns', { accountScoped: true });
  }

  options() {
    return axios.get(`${this.url}/options`);
  }

  preview(body) {
    return axios.post(`${this.url}/preview`, body);
  }

  test(body) {
    return axios.post(`${this.url}/test`, body);
  }

  testEmail(body) {
    return axios.post(`${this.url}/test_email`, body);
  }

  // Lista fría de correos (CSV) a una campaña Guardada.
  uploadList(id, file, name, cleanupDays) {
    const data = new FormData();
    data.append('file', file);
    if (name) data.append('name', name);
    data.append('cleanup_days', cleanupDays || 30);
    return axios.post(`${this.url}/${id}/list`, data);
  }

  check(id) {
    return axios.get(`${this.url}/${id}/check`);
  }

  launch(id) {
    return axios.post(`${this.url}/${id}/launch`);
  }

  results(id) {
    return axios.get(`${this.url}/${id}/results`);
  }

  contacts(id, group) {
    return axios.get(`${this.url}/${id}/contacts`, { params: { group } });
  }

  insights(id) {
    return axios.post(`${this.url}/${id}/insights`);
  }

  followUp(id, group, name) {
    return axios.post(`${this.url}/${id}/follow_up`, { group, name });
  }

  duplicate(id) {
    return axios.post(`${this.url}/${id}/duplicate`);
  }
}

export default new Motor2CampaignsAPI();
