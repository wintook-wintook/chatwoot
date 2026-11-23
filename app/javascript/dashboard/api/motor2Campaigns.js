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

  // «Simular»: la campaña completa para un contacto, sin mandar nada.
  simulate(id, contactId) {
    return axios.post(`${this.url}/${id}/simulate`, { contact_id: contactId });
  }

  // «Prueba real»: a los contactos de prueba, con los toques cada pocos minutos.
  testRun(id) {
    return axios.get(`${this.url}/${id}/test_run`);
  }

  startTestRun(id, recipients, everyMinutes) {
    return axios.post(`${this.url}/${id}/test_run`, {
      recipients,
      every_minutes: everyMinutes,
    });
  }

  stopTestRun(id) {
    return axios.delete(`${this.url}/${id}/test_run`);
  }

  // «Imágenes y archivos de esta oferta» (Motor2Campaigns::FilesController).
  files(id) {
    return axios.get(`${this.url}/${id}/files`);
  }

  uploadFile(id, file, about) {
    const data = new FormData();
    data.append('file', file);
    if (about) data.append('about', about);
    return axios.post(`${this.url}/${id}/files`, data);
  }

  updateFile(id, fileId, rules) {
    return axios.patch(`${this.url}/${id}/files/${fileId}`, { rules });
  }

  removeFile(id, fileId) {
    return axios.delete(`${this.url}/${id}/files/${fileId}`);
  }
}

export default new Motor2CampaignsAPI();
