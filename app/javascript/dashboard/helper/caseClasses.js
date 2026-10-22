// @tickets_cases — Plan-Casos E1 (F6): clases de caso en la navegación.
// Una sola fuente para el selector, las rutas y los títulos. Agregar Órdenes de
// trabajo o Proyectos = una entrada aquí (con su flag) + su slug en la ruta.
import { FEATURE_FLAGS } from '../featureFlags';

// Orden de aparición en el selector (decisión: Comercial primero).
export const CASE_CLASSES = [
  {
    key: 'commercial',
    flag: FEATURE_FLAGS.CASE_COMMERCIAL,
    color: '#8b5cf6',
    i18n: 'CASE_TICKETS.CLASSES.COMMERCIAL',
  },
  {
    key: 'support',
    flag: null,
    color: '#3b82f6',
    i18n: 'CASE_TICKETS.CLASSES.SUPPORT',
  },
  // Plan-Clase-Orden-de-Trabajo F1.
  {
    key: 'work_order',
    flag: FEATURE_FLAGS.CASE_WORK_ORDER,
    color: '#0d9488',
    i18n: 'CASE_TICKETS.CLASSES.WORK_ORDER',
  },
  // Plan-Clase-Proyecto P1.
  {
    key: 'project',
    flag: FEATURE_FLAGS.CASE_PROJECT,
    color: '#6366f1',
    i18n: 'CASE_TICKETS.CLASSES.PROJECT',
  },
];

export const DEFAULT_CASE_CLASS = 'support';

// Espejo de CaseType::CLASS_CAPABILITIES: solo Soporte lleva SLA (aviso de SLA
// vencido, punto de SLA en el folio).
const SLA_CLASSES = ['support'];
export const classHasSla = caseClass => SLA_CLASSES.includes(caseClass);

const classEntry = caseClass =>
  CASE_CLASSES.find(c => c.key === caseClass) ||
  CASE_CLASSES.find(c => c.key === DEFAULT_CASE_CLASS);

// Base i18n de la clase (CASE_TICKETS.CLASSES.<CLASE>); desconocida → Soporte.
export const classI18nBase = caseClass => classEntry(caseClass).i18n;

// Slugs válidos en la ruta `tickets/:caseClass/...`.
export const CASE_CLASS_PATTERN = CASE_CLASSES.map(c => c.key).join('|');

// Vistas que existen por clase → nombre de ruta.
export const CLASS_VIEW_ROUTES = {
  list: 'gestorTickets_class_list',
  board: 'gestorTickets_class_board',
  metrics: 'gestorTickets_class_metrics',
};

export const enabledCaseClasses = isEnabled =>
  CASE_CLASSES.filter(c => !c.flag || isEnabled(c.flag));

// Tipos con los que se puede CREAR (o al que se puede cambiar) un caso: sin los
// retirados (cambiaron de clase; conservan sus casos, no reciben nuevos). Los
// filtros de Lista y Tablero sí los muestran, para seguir trabajando esos casos.
export const creatableTypes = (types, keepId = null) =>
  (types || []).filter(
    t => !t.retired || (keepId !== null && String(t.id) === String(keepId))
  );

// ── Estado guardado (Plan-Casos E1.2) ──────────────────────────────────────
// Todo lo que el agente deja elegido se recuerda en localStorage, por cuenta:
// la última clase, y POR CLASE un solo objeto que comparten Lista, Tablero y
// Métricas (tipo, ¿de quién?, SLA, filtros finos, búsqueda) más lo propio de
// cada vista (`list`, `metrics`). Sobrevive a recargar y a salir del módulo.
// localStorage puede no existir o lanzar (modo privado): nunca rompe la vista.
const read = key => {
  try {
    return window.localStorage.getItem(key);
  } catch (_e) {
    return null;
  }
};
const write = (key, value) => {
  try {
    window.localStorage.setItem(key, value);
  } catch (_e) {
    // sin almacenamiento: cada visita arranca con los valores por defecto
  }
};

const classKey = accountId => `cases.lastClass.${accountId}`;
const stateKey = (accountId, caseClass) =>
  `cases.state.${accountId}.${caseClass}`;

export const rememberCaseClass = (accountId, caseClass) =>
  write(classKey(accountId), caseClass);

export const lastCaseClass = accountId => {
  const value = read(classKey(accountId));
  return CASE_CLASSES.some(c => c.key === value) ? value : DEFAULT_CASE_CLASS;
};

export const loadCaseState = (accountId, caseClass) => {
  try {
    return JSON.parse(read(stateKey(accountId, caseClass))) || {};
  } catch (_e) {
    return {};
  }
};

// Mezcla `patch` sobre lo guardado (las claves que no vienen se conservan).
export const saveCaseState = (accountId, caseClass, patch) =>
  write(
    stateKey(accountId, caseClass),
    JSON.stringify({ ...loadCaseState(accountId, caseClass), ...patch })
  );

// Plan-Casos E1.1 — tipos de una clase (un tipo sin clase cuenta como Soporte).
export const typesOfClass = (types, caseClass) =>
  (types || []).filter(t => (t.case_class || DEFAULT_CASE_CLASS) === caseClass);

// El tipo elegido por clase vive en el mismo estado. '' = todos.
export const rememberCaseType = (accountId, caseClass, typeId) =>
  saveCaseState(accountId, caseClass, { type: typeId ?? '' });

export const lastCaseType = (accountId, caseClass) => {
  const { type } = loadCaseState(accountId, caseClass);
  return type === undefined || type === null || type === '' ? '' : Number(type);
};

export const caseClassOfTicket = ticket =>
  classEntry(ticket?.case_type?.case_class).key;
