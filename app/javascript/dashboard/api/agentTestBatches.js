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

  run(batchId, templateId) {
    return axios.post(`${this.url}/${batchId}/run`, {
      template_id: templateId,
    });
  }

  list(templateId) {
    return axios.get(this.url, {
      params: templateId ? { template_id: templateId } : {},
    });
  }

  runCorrections(templateId) {
    return axios.post(`${this.url}/run_corrections`, {
      template_id: templateId,
    });
  }

  runs(runId) {
    return axios.get(`${this.url}/runs${runId ? `/${runId}` : ''}`);
  }
}

export default new AgentTestBatchesAPI();
