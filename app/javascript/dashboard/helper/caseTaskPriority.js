// @tickets_cases — Plan-Bandeja-Prioridad F1: utilidades de «Mi día» (duración
// estimada y motivos del puntaje), compartidas por la bandeja y los formularios.

// Opciones del combo «Duración estimada» (minutos). '' = sin estimar.
export const ESTIMATE_OPTIONS = [15, 30, 45, 60, 90, 120, 180, 240, 360, 480];

// 90 → "1 h 30 min" · 45 → "45 min" · 120 → "2 h" · vacío → ''.
export const formatMinutes = minutes => {
  const total = Number(minutes);
  if (!total || total < 0) return '';
  const h = Math.floor(total / 60);
  const m = total % 60;
  if (!h) return `${m} min`;
  return m ? `${h} h ${m} min` : `${h} h`;
};

// Tono de la etiqueta de cada motivo: rojo = algo ya vencido, ámbar = vence
// pronto o está en riesgo, gris = el resto (prioridad, antigüedad, espera).
const RED = ['overdue', 'sla_overdue', 'project_overdue', 'visit_overdue'];
const AMBER = [
  'due_today',
  'due_tomorrow',
  'sla_at_risk',
  'visit_today',
  'project_due_soon',
  'close_soon',
  'priority_urgent',
  'case_urgent',
  'planned_missed',
];

export const REASON_TONE = {
  red: 'bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300',
  amber: 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300',
  slate: 'bg-slate-100 text-slate-600 dark:bg-slate-700/60 dark:text-slate-300',
};

export const reasonTone = key => {
  if (RED.includes(key)) return 'red';
  if (AMBER.includes(key)) return 'amber';
  return 'slate';
};

// Motivos a mostrar: los que más suman primero; la antigüedad solo si no hay
// otra cosa que decir (es el desempate, no la razón).
export const visibleReasons = (reasons, max = 3) => {
  const list = (reasons || []).filter(r => r.points > 0);
  const main = list.filter(r => r.key !== 'age');
  const sorted = (main.length ? main : list).sort(
    (a, b) => b.points - a.points
  );
  return sorted.slice(0, max);
};

// ── F2 — orden propio ──────────────────────────────────────────────────────

const pad = n => String(n).padStart(2, '0');

// Fecha LOCAL 'YYYY-MM-DD' (el plan del día es del día del agente, no del
// servidor, que corre en UTC).
export const localDay = (date = new Date()) =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;

// 'YYYY-MM-DD' + n días (fechas sin hora: «Programada para»).
export const addDays = (day, n) => {
  const [y, m, d] = day.split('-').map(Number);
  return localDay(new Date(y, m - 1, d + n));
};

// ¿Programada después de su vencimiento? (quedará vencida). `dueAt` con hora.
export const plannedAfterDue = (plannedOn, dueAt) =>
  !!plannedOn && !!dueAt && plannedOn > localDay(new Date(dueAt));
