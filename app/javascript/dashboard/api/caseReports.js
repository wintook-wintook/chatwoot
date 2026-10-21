/* global axios */
// proyecto@metricas_casos
import ApiClient from './ApiClient';

const getTimeOffset = () => -new Date().getTimezoneOffset() / 60;

// currency / close: pestaña Embudo de Comercial (solo el reporte pipeline los usa).
// prevFrom / prevTo: rango de comparación del ▲▼; span: ventana de «Mes a mes».
const filterParams = ({
  caseTypeId,
  assigneeId,
  teamId,
  from,
  to,
  prevFrom,
  prevTo,
  currency,
  close,
  thresholdDays,
  span,
} = {}) => ({
  case_type_id: caseTypeId,
  assignee_id: assigneeId,
  team_id: teamId,
  since: from,
  until: to,
  prev_since: prevFrom,
  prev_until: prevTo,
  currency,
  close,
  threshold_days: thresholdDays,
  span,
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

  // Plan-Metricas-Comercial — a pedido (botón «Calcular»).
  getPipelineStale(filters = {}) {
    return axios.get(`${this.url}/pipeline_stale`, {
      params: filterParams(filters),
    });
  }

  getPipelineMonthly(filters = {}) {
    return axios.get(`${this.url}/pipeline_monthly`, {
      params: filterParams(filters),
    });
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

  // «Resumen del negocio» (administradores y autorizados).
  getBusinessSummary(filters = {}) {
    return axios.get(`${this.url}/business_summary`, {
      params: filterParams(filters),
    });
  }

  // «Explícame la semana»: el período se manda como lo ve el dueño.
  explainBusinessSummary({ periodLabel, compareLabel, ...filters } = {}) {
    return axios.post(`${this.url}/business_summary_ai`, {
      ...filterParams(filters),
      period_label: periodLabel,
      compare_label: compareLabel,
    });
  }

  // Análisis de conversaciones con IA (a pedido): muestra del período.
  analyzeConversations(filters = {}) {
    return axios.post(
      `${this.url}/business_summary_conversations_ai`,
      filterParams(filters)
    );
  }

  getStalled({ thresholdDays, ...filters } = {}) {
    return axios.get(`${this.url}/stalled`, {
      params: { ...filterParams(filters), threshold_days: thresholdDays },
    });
  }
}

export default new CaseReportsAPI();
