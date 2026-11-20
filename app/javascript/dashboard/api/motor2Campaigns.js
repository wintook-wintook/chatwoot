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
