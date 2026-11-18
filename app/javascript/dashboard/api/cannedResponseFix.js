/* global axios */

import ApiClient from './ApiClient';

// proyecto@arreglar_predefinidas — «Arreglar con IA».
class CannedResponseFix extends ApiClient {
  constructor() {
    super('canned_response_fixes', { accountScoped: true });
  }

  // La última propuesta vigente de una predefinida (o null).
  latest(cannedResponseId) {
    return axios.get(this.cannedUrl(cannedResponseId));
  }

  // Pedir una propuesta nueva: se arma en segundo plano (status running).
  propose(cannedResponseId) {
    return axios.post(this.cannedUrl(cannedResponseId));
  }

  // F2: la última vigente de un hallazgo para un tipo de arreglo (o null).
  forFinding(findingId, kind) {
    return axios.get(this.url, { params: { finding_id: findingId, kind } });
  }

  // F2: pedir un arreglo de un hallazgo. kind: writing | merge | separate | resolve.
  // resolve: choices [{ choice: 'a'|'b'|'custom', value }], extraIds de «también aparece en».
  create({ kind, findingId, choices, extraIds }) {
    return axios.post(this.url, {
      kind,
      finding_id: findingId,
      choices,
      extra_ids: extraIds,
    });
  }

  // Contradicción: qué queda prohibido y en qué otras respuestas aparece.
  resolvePreview(findingId, choices) {
    return axios.post(`${this.url}/resolve_preview`, {
      finding_id: findingId,
      choices,
    });
  }

  // «Corregir todas» (ortografía y numeración) → { batch, count }.
  bulkWriting() {
    return axios.post(`${this.url}/bulk_writing`);
  }

  batch(batchId) {
    return axios.get(this.url, { params: { batch: batchId } });
  }

  // Aplicados y deshechos de los últimos 30 días.
  history() {
    return axios.get(this.url, { params: { history: 1 } });
  }

  // force: deshacer aunque alguien haya editado después lo que dejó el arreglo.
  undo(fixId, force = false) {
    return axios.post(`${this.url}/${fixId}/undo`, { force });
  }

  status(fixId) {
    return axios.get(`${this.url}/${fixId}`);
  }

  // Candados sobre las partes como quedaron después de editarlas.
  check(fixId, parts) {
    return axios.post(`${this.url}/${fixId}/check`, { parts });
  }

  // force: aceptar aunque falten datos (la persona confirmó que ya no aplican).
  apply(fixId, parts, force = false) {
    return axios.post(`${this.url}/${fixId}/apply`, { parts, force });
  }

  discard(fixId) {
    return axios.post(`${this.url}/${fixId}/discard`);
  }

  cannedUrl(cannedResponseId) {
    return this.url.replace(
      /canned_response_fixes$/,
      `canned_responses/${cannedResponseId}/fix`
    );
  }
}

export default new CannedResponseFix();
