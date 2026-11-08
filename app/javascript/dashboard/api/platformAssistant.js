/* global axios */
// Asistente (Dali) — el asistente conversacional de toda la plataforma. Archivo
// aparte de api/assistant.js, que es el Asistente de Agentes IA (Entrenamiento).
import ApiClient from './ApiClient';
import { browserZone } from './fieldVisits';

class AssistantAPI extends ApiClient {
  constructor() {
    super('assistant', { accountScoped: true });
  }

  show() {
    return axios.get(this.url, { params: { tz: browserZone() } });
  }

  // `context`: lo que el usuario está viendo (página, caso, contacto…).
  send(content, context) {
    return axios.post(`${this.url}/messages`, {
      content,
      context,
      tz: browserZone(),
    });
  }

  reset() {
    return axios.post(`${this.url}/reset`);
  }

  confirm(proposalId, payload) {
    return axios.post(`${this.url}/proposals/${proposalId}/confirm`, {
      payload,
      tz: browserZone(),
    });
  }

  cancel(proposalId) {
    return axios.post(`${this.url}/proposals/${proposalId}/cancel`);
  }

  // Lo que dictó (nota de voz del navegador) → { text }.
  transcribe(blob) {
    const form = new FormData();
    const ext = (blob.type.match(/audio\/(\w+)/) || [])[1] || 'webm';
    form.append('audio', blob, `dictado.${ext}`);
    return axios.post(`${this.url}/transcribe`, form);
  }

  // Enlace de un solo uso (5 min) para entrar firmado al portal de Dali en el teléfono.
  mobileLink() {
    return axios.post(`${this.url}/mobile_link`);
  }

  rename(name) {
    return axios.patch(`${this.url}/settings`, { name });
  }

  // Nombre y modelos (general y de análisis); vacío = el de siempre. Solo administradores.
  saveSettings({ name, model, analysisModel }) {
    return axios.patch(`${this.url}/settings`, {
      name,
      model: model || '',
      analysis_model: analysisModel || '',
    });
  }
}

export default new AssistantAPI();
