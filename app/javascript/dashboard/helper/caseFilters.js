// @tickets_cases — Plan-Casos E1.1: filtros de Lista y Tablero, por niveles.
//   clase → tipo (encabezado) → ¿de quién? (pestañas) → estado → búsqueda →
//   filtros finos (botón «Filtros»). Aquí viven los filtros finos: qué ofrece
//   cada clase y cómo se traducen a parámetros de la API.
import { isoDayFromToday } from './caseCommercial';

// ¿De quién? — mismas claves en todas las clases (las etiquetas cambian).
export const SCOPES = ['mine', 'unassigned', 'all'];

export const emptyFineFilters = () => ({
  priority: '',
  origin: '',
  affected_service_id: '',
  category_id: '',
  ticket_kind: '',
  assignee_id: '',
  created_from: '',
  created_to: '',
  close: '', // Comercial: this_month | next_30 | overdue
  closed: '', // fecha en que se cerró: this_month | last_month | last_30 | last_90
  visit: '', // Orden de trabajo: today | this_week | overdue
  billable: '', // Orden de trabajo: yes | no
  due: '', // Proyecto: fecha objetivo this_month | next_30 | overdue
});

// Qué filtros finos tiene cada clase, en el orden en que se muestran.
// Origen no aplica a una venta; naturaleza ITIL solo si el tipo usa ITIL.
// Las fechas dependen de lo que se ve (ver fineKeyApplies).
export const FINE_FILTERS_BY_CLASS = {
  support: [
    'priority',
    'origin',
    'affected_service_id',
    'category_id',
    'ticket_kind',
    'assignee_id',
    'closed',
    'created',
  ],
  commercial: ['close', 'closed', 'priority', 'assignee_id', 'created'],
  // Plan-Clase-Orden-de-Trabajo — como Soporte sin origen ni naturaleza ITIL,
  // más la visita programada y facturable (F2b).
  work_order: [
    'visit',
    'billable',
    'priority',
    'affected_service_id',
    'category_id',
    'assignee_id',
    'closed',
    'created',
  ],
  // Plan-Clase-Proyecto P1 — fecha objetivo (mismos rangos que el cierre estimado).
  project: ['due', 'priority', 'assignee_id', 'closed', 'created'],
};

// Plan-Casos E1.3 — resultado de una oportunidad en la Lista (combo), en este
// orden (decisión del usuario). «En curso» (active) = abiertas sin pospuestas;
// «Pospuestas» también es abierta; las otras tres, cerradas. '' = Todas.
export const COMMERCIAL_RESULTS = [
  'active',
  'won',
  'lost',
  'postponed',
  'cancelled',
];
export const DEFAULT_COMMERCIAL_RESULT = 'active';

// Plan-Clase-Orden-de-Trabajo F2b — etapa de una orden en la Lista (combo),
// espejo del flujo de columnas por defecto (CaseTypeColumn::WORK_ORDER_TEMPLATE).
// «Abiertas» = todo lo pendiente; '' = Todas.
export const WORK_ORDER_STAGES = {
  open: null,
  to_schedule: ['open', 'classified'],
  scheduled: ['assigned', 'in_diagnosis'],
  in_execution: ['in_progress', 'escalated'],
  paused: [
    'waiting_on_customer',
    'waiting_on_third_party',
    'waiting_on_internal',
  ],
  finished: ['resolved', 'validating'],
  closed: ['closed'],
  cancelled: ['cancelled'],
};
export const WORK_ORDER_STAGE_KEYS = Object.keys(WORK_ORDER_STAGES);
export const DEFAULT_WORK_ORDER_STAGE = 'open';

// Plan-Clase-Proyecto P1 — fases de un proyecto (CaseTypeColumn::PROJECT_TEMPLATE).
export const PROJECT_STAGES = {
  open: null,
  planning: ['open', 'classified', 'assigned', 'in_diagnosis'],
  execution: ['in_progress', 'escalated'],
  paused: [
    'waiting_on_customer',
    'waiting_on_third_party',
    'waiting_on_internal',
  ],
  delivery: ['resolved', 'validating'],
  closed: ['closed'],
  cancelled: ['cancelled'],
};

// Clases con combo de etapa en la Lista (en vez de Pendientes/Cerrados).
export const CLASS_STAGES = {
  work_order: WORK_ORDER_STAGES,
  project: PROJECT_STAGES,
};
export const hasStages = caseClass => !!CLASS_STAGES[caseClass];
export const stageKeys = caseClass =>
  Object.keys(CLASS_STAGES[caseClass] || {});

// Etapas en las que el caso sigue abierto (aplican la visita / fecha objetivo y
// el aviso; no la fecha de cierre).
const OPEN_STAGES = [
  'open',
  'to_schedule',
  'scheduled',
  'in_execution',
  'planning',
  'execution',
  'paused',
];

// Etapa → parámetros del index (`status=pending` o `statuses=a,b`).
export const stageToParams = (stage, caseClass = 'work_order') => {
  if (!stage) return {};
  if (stage === 'open') return { status: 'pending' };
  const list = (CLASS_STAGES[caseClass] || {})[stage];
  return list ? { statuses: list.join(',') } : {};
};
export const statusForResult = result =>
  ['active', 'postponed'].includes(result) ? 'pending' : 'closed';

// Plan-Casos E1.3 — mismo período en las dos Métricas.
export const METRIC_PERIODS = [
  { key: '7d', days: 7 },
  { key: '30d', days: 30 },
  { key: '90d', days: 90 },
  { key: '365d', days: 365 },
  { key: 'all', days: null },
];

// Plan-Casos E1.3 — cerrados en el Tablero: ocultar, por días o todos.
export const BOARD_CLOSED_OPTIONS = ['hide', '7', '30', '90', 'all'];
export const DEFAULT_BOARD_CLOSED = '30';

export const CLOSE_PRESETS = ['this_month', 'next_30', 'overdue'];
export const CLOSED_PRESETS = [
  'this_month',
  'last_month',
  'last_30',
  'last_90',
];
export const VISIT_PRESETS = ['today', 'this_week', 'overdue'];
export const BILLABLE_OPTIONS = ['yes', 'no'];

const OPEN_RESULTS = ['active', 'postponed'];
const CLOSED_RESULTS = ['won', 'lost', 'cancelled'];

// ¿El filtro fino tiene sentido con lo que se está viendo?
//   · Cierre estimado: solo si puede haber abiertas (no en Ganadas/Perdidas/Canceladas).
//   · Fecha de cierre: solo si puede haber cerradas (no en En curso/Pospuestas ni
//     en Pendientes) y nunca en el Tablero (tiene su propio selector de cerrados).
//   · Visita (orden): solo mientras la orden pueda seguir abierta.
// `ctx`: { itil, status, outcome, stage, board }.
export const fineKeyApplies = (key, caseClass, scope, ctx = {}) => {
  if (key === 'assignee_id') return scope === 'all';
  if (key === 'ticket_kind') return !!ctx.itil;
  if (key === 'close') return !CLOSED_RESULTS.includes(ctx.outcome);
  if (key === 'visit' || key === 'due')
    return !ctx.stage || OPEN_STAGES.includes(ctx.stage);
  if (key === 'closed') {
    if (ctx.board) return false;
    if (caseClass === 'commercial') return !OPEN_RESULTS.includes(ctx.outcome);
    if (hasStages(caseClass)) return !OPEN_STAGES.includes(ctx.stage);
    return ctx.status !== 'pending';
  }
  return true;
};

const pad = n => String(n).padStart(2, '0');
const isoDay = d =>
  `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

// Preset de cierre estimado → { from, to } en YYYY-MM-DD.
export const closeRange = preset => {
  const now = new Date();
  if (preset === 'this_month') {
    return {
      from: isoDay(new Date(now.getFullYear(), now.getMonth(), 1)),
      to: isoDay(new Date(now.getFullYear(), now.getMonth() + 1, 0)),
    };
  }
  if (preset === 'next_30')
    return { from: isoDayFromToday(0), to: isoDayFromToday(30) };
  if (preset === 'overdue') return { from: '', to: isoDayFromToday(-1) };
  return { from: '', to: '' };
};

// Aviso rojo por clase (Lista y Tablero): Soporte = SLA vencido; Orden de
// trabajo = visita vencida; Comercial = cierre estimado vencido. Solo aplica si
// lo que se ve puede tener abiertos (no en Cerrados, Ganadas, Terminadas…).
export const alertApplies = ({ caseClass, status, outcome, stage } = {}) => {
  if (caseClass === 'commercial') return !CLOSED_RESULTS.includes(outcome);
  if (hasStages(caseClass)) return !stage || OPEN_STAGES.includes(stage);
  return status !== 'closed';
};

// Parámetros que agrega el aviso de Órdenes / Comercial (el de Soporte es
// `sla_status=overdue`, lo arma cada vista con el estado).
export const classAlertParams = caseClass => {
  if (caseClass === 'work_order') return { visit_overdue: true };
  if (caseClass === 'commercial')
    return { expected_close_to: isoDayFromToday(-1), status: 'pending' };
  if (caseClass === 'project')
    return { project_due_to: isoDayFromToday(-1), status: 'pending' };
  return {};
};

// Preset de visita → parámetros (`visit_from`/`visit_to` o `visit_overdue`).
// La semana va de lunes a domingo.
export const visitToParams = preset => {
  if (preset === 'today') {
    const today = isoDayFromToday(0);
    return { visit_from: today, visit_to: today };
  }
  if (preset === 'this_week') {
    const offset = (new Date().getDay() + 6) % 7; // días desde el lunes
    return {
      visit_from: isoDayFromToday(-offset),
      visit_to: isoDayFromToday(6 - offset),
    };
  }
  if (preset === 'overdue') return { visit_overdue: true };
  return {};
};

// Preset de fecha de cierre (ya ocurrida) → { from, to } en YYYY-MM-DD.
export const closedRange = preset => {
  const now = new Date();
  const y = now.getFullYear();
  const m = now.getMonth();
  if (preset === 'this_month')
    return { from: isoDay(new Date(y, m, 1)), to: isoDayFromToday(0) };
  if (preset === 'last_month')
    return {
      from: isoDay(new Date(y, m - 1, 1)),
      to: isoDay(new Date(y, m, 0)),
    };
  if (preset === 'last_30')
    return { from: isoDayFromToday(-30), to: isoDayFromToday(0) };
  if (preset === 'last_90')
    return { from: isoDayFromToday(-90), to: isoDayFromToday(0) };
  return { from: '', to: '' };
};

// Claves de filtro activas que aplican a la clase y a lo que se ve. Un filtro
// que deja de aplicar (p. ej. cierre estimado al pasar a Ganadas) no se borra:
// solo no cuenta ni se manda, y vuelve si se regresa a donde aplicaba.
// `assignee_id` solo cuenta en «Todos».
export const activeFineKeys = (filters, caseClass, scope, ctx = {}) => {
  const allowed = FINE_FILTERS_BY_CLASS[caseClass] || [];
  return allowed.filter(key => {
    if (!fineKeyApplies(key, caseClass, scope, ctx)) return false;
    if (key === 'created')
      return !!(filters.created_from || filters.created_to);
    return !!filters[key];
  });
};

// Filtros finos → parámetros del index de case_tickets.
export const fineFiltersToParams = (filters, caseClass, scope, opts = {}) => {
  const params = {};
  activeFineKeys(filters, caseClass, scope, opts).forEach(key => {
    if (key === 'created') {
      if (filters.created_from) params.date_from = filters.created_from;
      if (filters.created_to) params.date_to = filters.created_to;
    } else if (key === 'close') {
      const { from, to } = closeRange(filters.close);
      if (from) params.expected_close_from = from;
      if (to) params.expected_close_to = to;
    } else if (key === 'closed') {
      const { from, to } = closedRange(filters.closed);
      if (from) params.closed_from = from;
      if (to) params.closed_to = to;
    } else if (key === 'due') {
      const { from, to } = closeRange(filters.due);
      if (from) params.project_due_from = from;
      if (to) params.project_due_to = to;
    } else if (key === 'visit') {
      Object.assign(params, visitToParams(filters.visit));
    } else if (key === 'billable') {
      params.billable = filters.billable === 'yes';
    } else {
      params[key] = filters[key];
    }
  });
  return params;
};

// ¿De quién? → assignee_id para la API.
export const scopeToParams = (scope, currentUserId) => {
  if (scope === 'mine') return { assignee_id: currentUserId };
  if (scope === 'unassigned') return { assignee_id: 'null' };
  return {};
};
