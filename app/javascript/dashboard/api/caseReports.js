/* global axios */
// proyecto@metricas_casos
import ApiClient from './ApiClient';

const getTimeOffset = () => -new Date().getTimezoneOffset() / 60;

const filterParams = ({ caseTypeId, assigneeId, teamId, from, to } = {}) => ({
  case_type_id: caseTypeId,
  assignee_id: assigneeId,
  team_id: teamId,
  since: from,
  until: to,
});

class CaseReportsAPI extends ApiClient {
  constructor() {
    super('case_reports', { accountScoped: true, apiVersion: 'v2' });
  }

  getFunnel(filters = {}) {
    return axios.get(`${this.url}/funnel`, { params: filterParams(filters) });
  }

  getOutcome(filters = {}) {
    return axios.get(`${this.url}/outcome`, { params: filterParams(filters) });
  }

  getTimeseries({ groupBy, ...filters } = {}) {
    return axios.get(`${this.url}/timeseries`, {
      params: {
        ...filterParams(filters),
        group_by: groupBy,
        timezone_offset: getTimeOffset(),
      },
    });
  }

  getAssignees(filters = {}) {
    return axios.get(`${this.url}/assignees`, {
      params: filterParams(filters),
    });
  }

  getVelocity(filters = {}) {
    return axios.get(`${this.url}/velocity`, { params: filterParams(filters) });
  }

  // Plan-Clase-Comercial F5 — métricas del embudo comercial.
  getPipeline(filters = {}) {
    return axios.get(`${this.url}/pipeline`, { params: filterParams(filters) });
  }

  // Plan-Clase-Proyecto P3 — métricas de proyectos.
  getProjects(filters = {}) {
    return axios.get(`${this.url}/projects`, { params: filterParams(filters) });
  }

  // Plan-Clase-Orden-de-Trabajo F3 — métricas de órdenes de trabajo.
  getWorkOrders(filters = {}) {
    return axios.get(`${this.url}/work_orders`, {
      params: filterParams(filters),
    });
  }

  getStalled({ thresholdDays, ...filters } = {}) {
    return axios.get(`${this.url}/stalled`, {
      params: { ...filterParams(filters), threshold_days: thresholdDays },
    });
  }
}

export default new CaseReportsAPI();
