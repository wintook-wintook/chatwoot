/* global axios */
// Probador de agentes — lotes de pruebas y sus corridas.
import ApiClient from './ApiClient';

class AgentTestBatchesAPI extends ApiClient {
  constructor() {
    super('agent_test_batches', { accountScoped: true });
  }

  addCase(batchId, testCase) {
    return axios.post(`${this.url}/${batchId}/cases`, testCase);
  }

  removeCase(batchId, caseId) {
    return axios.delete(`${this.url}/${batchId}/cases/${caseId}`);
  }

  // seleccion: 'on' (búsqueda nueva) | 'off' (la de siempre) | '' (la de la cuenta).
  run(batchId, templateId, seleccion = '') {
    return axios.post(`${this.url}/${batchId}/run`, {
      template_id: templateId,
      seleccion: seleccion || undefined,
    });
  }

  // Las mismas pruebas con la búsqueda nueva y con la de siempre.
  compare(batchId, templateId) {
    return axios.post(`${this.url}/${batchId}/compare`, {
      template_id: templateId,
    });
  }

  // Lote desde lo pegado de una hoja (mensajes | esperado | variables).
  importRows(templateId, rows, name = '') {
    return axios.post(`${this.url}/import`, {
      template_id: templateId,
      rows,
      name: name || undefined,
    });
  }

  importPila(templateId) {
    return axios.post(`${this.url}/import_pila`, { template_id: templateId });
  }

  list(templateId) {
    return axios.get(this.url, {
      params: templateId ? { template_id: templateId } : {},
    });
  }

  runCorrections(templateId, seleccion = '') {
    return axios.post(`${this.url}/run_corrections`, {
      template_id: templateId,
      seleccion: seleccion || undefined,
    });
  }

  runs(runId) {
    return axios.get(`${this.url}/runs${runId ? `/${runId}` : ''}`);
  }
}

export default new AgentTestBatchesAPI();
