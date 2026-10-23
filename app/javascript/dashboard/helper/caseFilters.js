// @tickets_cases — Plan-Casos E1.1: filtros de Lista y Tablero, por niveles.
//   clase → tipo (encabezado) → ¿de quién? (pestañas) → estado → búsqueda →
//   filtros finos (botón «Filtros»). Aquí viven los filtros finos: qué ofrece
//   cada clase y cómo se traducen a parámetros de la API.
import { isoDayFromToday } from './caseCommercial';

// ¿De quién? — mismas claves en todas las clases (las etiquetas cambian).
export const SCOPES = ['mine', 'unassigned', 'all'];

// Plan-Metricas-Comercial — UNA sola fecha a la vez (decisión del usuario):
// «¿Qué fecha?» (`date_field`, ver DATE_FIELDS_BY_CLASS) + «¿Cuándo?»
// (`date_preset`; `custom` usa `date_from`/`date_to`, YYYY-MM-DD). Antes había
// un filtro por cada fecha (close, closed, created_*, visit, due) y no se
// entendía cuál era cuál; normalizeFineFilters traduce lo guardado.
export const emptyFineFilters = () => ({
  priority: '',
  origin: '',
  affected_service_id: '',
  category_id: '',
  ticket_kind: '',
  assignee_id: '',
  billable: '', // Orden de trabajo: yes | no
  date_field: '',
  date_preset: '',
  date_from: '',
  date_to: '',
});

// Qué filtros finos tiene cada clase, en el orden en que se muestran (`date`
// es el bloque de fecha, siempre primero). Origen no aplica a una venta;
// naturaleza ITIL solo si el tipo usa ITIL.
export const FINE_FILTERS_BY_CLASS = {
  support: [
    'date',
    'priority',
    'origin',
    'affected_service_id',
    'category_id',
    'ticket_kind',
    'assignee_id',
  ],
  commercial: ['date', 'priority', 'assignee_id'],
  // Plan-Clase-Orden-de-Trabajo — como Soporte sin origen ni naturaleza ITIL,
  // más facturable (F2b).
  work_order: [
    'date',
    'billable',
    'priority',
    'affected_service_id',
    'category_id',
    'assignee_id',
  ],
  project: ['date', 'priority', 'assignee_id'],
};

// «¿Qué fecha?» por clase; la primera es la que se ofrece de entrada.
//   close  cierre estimado / fecha comprometida (Comercial)
//   visit  visita programada (Orden) · due  fecha objetivo (Proyecto)
//   closed cuándo se cerró (en Comercial: ganada o perdida) · created  alta
export const DATE_FIELDS_BY_CLASS = {
  support: ['created', 'closed'],
  commercial: ['close', 'closed', 'created'],
  work_order: ['visit', 'created', 'closed'],
  project: ['due', 'created', 'closed'],
};
// Fechas que miran hacia adelante (algo por pasar) y las que ya ocurrieron:
// cambian las opciones de «¿Cuándo?».
const FORWARD_DATE_FIELDS = ['close', 'visit', 'due'];
export const FORWARD_DATE_PRESETS = [
  'overdue',
  'today',
  'this_week',
  'next_week',
  'this_month',
  'next_month',
  'next_30',
  'custom',
];
export const PAST_DATE_PRESETS = [
  'today',
  'this_week',
  'this_month',
  'last_month',
  'last_30',
  'last_90',
  'custom',
];
export const datePresetsFor = field =>
  FORWARD_DATE_FIELDS.includes(field)
    ? FORWARD_DATE_PRESETS
    : PAST_DATE_PRESETS;

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

// Plan-Casos E1.3 — cerrados en el Tablero: ocultar, por días o todos.
export const BOARD_CLOSED_OPTIONS = ['hide', '7', '30', '90', 'all'];
export const DEFAULT_BOARD_CLOSED = '30';

export const BILLABLE_OPTIONS = ['yes', 'no'];

const OPEN_RESULTS = ['active', 'postponed'];
const CLOSED_RESULTS = ['won', 'lost', 'cancelled'];

// ¿Esa fecha tiene sentido con lo que se está viendo?
//   · Cierre / promesa: solo si puede haber abiertas (no en Ganadas/Perdidas/Canceladas).
//   · Cerrado el: solo si puede haber cerradas (no en En curso/Pospuestas ni en
//     Pendientes) y nunca en el Tablero (tiene su propio selector de cerrados).
//   · Visita / fecha objetivo: solo mientras pueda seguir abierto.
// `ctx`: { itil, status, outcome, stage, board }.
export const dateFieldApplies = (field, caseClass, ctx = {}) => {
  if (field === 'close') return !CLOSED_RESULTS.includes(ctx.outcome);
  if (field === 'visit' || field === 'due')
    return !ctx.stage || OPEN_STAGES.includes(ctx.stage);
  if (field === 'closed') {
    if (ctx.board) return false;
    if (caseClass === 'commercial') return !OPEN_RESULTS.includes(ctx.outcome);
    if (hasStages(caseClass)) return !OPEN_STAGES.includes(ctx.stage);
    return ctx.status !== 'pending';
  }
  return field === 'created';
};
export const availableDateFields = (caseClass, ctx = {}) =>
  (DATE_FIELDS_BY_CLASS[caseClass] || []).filter(f =>
    dateFieldApplies(f, caseClass, ctx)
  );

// La fecha que se muestra en el combo: la elegida si aplica; si no, la primera
// que aplica. (Un filtro de fecha que deja de aplicar no se borra: solo no
// cuenta, y vuelve al regresar a donde aplicaba.)
export const shownDateField = (filters, caseClass, ctx = {}) => {
  const available = availableDateFields(caseClass, ctx);
  return available.includes(filters.date_field)
    ? filters.date_field
    : available[0] || '';
};

// ¿El filtro fino tiene sentido con lo que se está viendo?
export const fineKeyApplies = (key, caseClass, scope, ctx = {}) => {
  if (key === 'assignee_id') return scope === 'all';
  if (key === 'ticket_kind') return !!ctx.itil;
  if (key === 'date') return availableDateFields(caseClass, ctx).length > 0;
  return true;
};

// Filtros guardados con la forma vieja (una clave por fecha) → la nueva. Se
// queda la primera fecha que haya: cierre/visita/objetivo, cerrado, alta.
export const normalizeFineFilters = (saved = {}) => {
  const { close, closed, visit, due, created_from, created_to, ...rest } =
    saved || {};
  const fine = { ...emptyFineFilters(), ...rest };
  if (fine.date_preset) return fine;
  const legacy = [
    ['close', close],
    ['visit', visit],
    ['due', due],
    ['closed', closed],
  ].find(([, preset]) => preset);
  if (legacy) {
    [fine.date_field, fine.date_preset] = legacy;
  } else if (created_from || created_to) {
    Object.assign(fine, {
      date_field: 'created',
      date_preset: 'custom',
      date_from: created_from || '',
      date_to: created_to || '',
    });
  }
  return fine;
};

const pad = n => String(n).padStart(2, '0');
const isoDay = d =>
  `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

// «¿Cuándo?» → { from, to } en YYYY-MM-DD (vacío = sin ese extremo). La
// semana va de lunes a domingo; `overdue` = hasta ayer.
export const dateRange = (preset, { from = '', to = '' } = {}) => {
  const now = new Date();
  const y = now.getFullYear();
  const m = now.getMonth();
  const monday = -((now.getDay() + 6) % 7); // días desde el lunes (≤ 0)
  switch (preset) {
    case 'overdue':
      return { from: '', to: isoDayFromToday(-1) };
    case 'today':
      return { from: isoDayFromToday(0), to: isoDayFromToday(0) };
    case 'this_week':
      return { from: isoDayFromToday(monday), to: isoDayFromToday(monday + 6) };
    case 'next_week':
      return {
        from: isoDayFromToday(monday + 7),
        to: isoDayFromToday(monday + 13),
      };
    case 'this_month':
      return {
        from: isoDay(new Date(y, m, 1)),
        to: isoDay(new Date(y, m + 1, 0)),
      };
    case 'next_month':
      return {
        from: isoDay(new Date(y, m + 1, 1)),
        to: isoDay(new Date(y, m + 2, 0)),
      };
    case 'last_month':
      return {
        from: isoDay(new Date(y, m - 1, 1)),
        to: isoDay(new Date(y, m, 0)),
      };
    case 'next_30':
      return { from: isoDayFromToday(0), to: isoDayFromToday(30) };
    case 'last_30':
      return { from: isoDayFromToday(-30), to: isoDayFromToday(0) };
    case 'last_90':
      return { from: isoDayFromToday(-90), to: isoDayFromToday(0) };
    case 'custom':
      return { from, to };
    default:
      return { from: '', to: '' };
  }
};

// Parámetros del index por fecha: [desde, hasta].
const DATE_PARAMS = {
  close: ['expected_close_from', 'expected_close_to'],
  due: ['project_due_from', 'project_due_to'],
  visit: ['visit_from', 'visit_to'],
  closed: ['closed_from', 'closed_to'],
  created: ['date_from', 'date_to'],
};

// Bloque de fecha → parámetros. La visita vencida es otra cosa que «visita
// hasta ayer» (sigue abierta con una visita cuya hora pasó): `visit_overdue`.
// La fecha elegida que deja de aplicar no salta a otra: solo no cuenta.
export const dateFilterParams = (filters, caseClass, ctx = {}) => {
  const field = filters.date_field || shownDateField(filters, caseClass, ctx);
  if (!field || !filters.date_preset) return {};
  if (!dateFieldApplies(field, caseClass, ctx)) return {};
  if (field === 'visit' && filters.date_preset === 'overdue')
    return { visit_overdue: true };
  const { from, to } = dateRange(filters.date_preset, {
    from: filters.date_from,
    to: filters.date_to,
  });
  const [fromKey, toKey] = DATE_PARAMS[field];
  const params = {};
  if (from) params[fromKey] = from;
  if (to) params[toKey] = to;
  return params;
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

// Claves de filtro activas que aplican a la clase y a lo que se ve. Un filtro
// que deja de aplicar (p. ej. cierre estimado al pasar a Ganadas) no se borra:
// solo no cuenta ni se manda, y vuelve si se regresa a donde aplicaba.
// `assignee_id` solo cuenta en «Todos».
export const activeFineKeys = (filters, caseClass, scope, ctx = {}) => {
  const allowed = FINE_FILTERS_BY_CLASS[caseClass] || [];
  return allowed.filter(key => {
    if (!fineKeyApplies(key, caseClass, scope, ctx)) return false;
    if (key === 'date')
      return Object.keys(dateFilterParams(filters, caseClass, ctx)).length > 0;
    return !!filters[key];
  });
};

// Filtros finos → parámetros del index de case_tickets.
export const fineFiltersToParams = (filters, caseClass, scope, opts = {}) => {
  const params = {};
  activeFineKeys(filters, caseClass, scope, opts).forEach(key => {
    if (key === 'date') {
      Object.assign(params, dateFilterParams(filters, caseClass, opts));
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
