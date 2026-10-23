// @tickets_cases — Plan-Clase-Comercial F4: utilidades de oportunidades
// compartidas por la lista, el Kanban, el detalle y los modales.

export const COMMERCIAL_CLASS = 'commercial';
export const OUTCOMES = ['won', 'lost', 'cancelled'];

export const isCommercialType = type => type?.case_class === COMMERCIAL_CLASS;

// Badge del resultado (Ganada/Perdida/Cancelada), mismo patrón de color del módulo:
// fondo suave + texto -800 (modo oscuro: fondo -900/40 + texto -300).
export const OUTCOME_BADGE = {
  won: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300',
  lost: 'bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300',
  cancelled:
    'bg-slate-100 text-slate-600 dark:bg-slate-700/60 dark:text-slate-300',
};

// Pospuesta = en espera: ámbar, igual que «En espera» en Soporte.
export const POSTPONED_BADGE =
  'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300';

// Plan-Metricas-Comercial — comprometida por el cliente (abierta) y promesa
// vencida (la fecha comprometida ya pasó sin ganarla).
export const COMMITTED_BADGE =
  'bg-teal-100 text-teal-800 dark:bg-teal-900/40 dark:text-teal-200';
export const PROMISE_OVERDUE_BADGE =
  'bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300';

// ¿Abierta y comprometida? ¿Y ya se le pasó la fecha prometida?
export const isOpenCommitted = ticket =>
  !!ticket &&
  !!ticket.committed &&
  !ticket.outcome &&
  !['closed', 'cancelled'].includes(ticket.status);
export const promiseOverdue = (ticket, today) =>
  isOpenCommitted(ticket) &&
  !!ticket.expected_close_at &&
  String(ticket.expected_close_at).slice(0, 10) < today;

// 25000.5 + 'MXN' → "$25,000.50 MXN". Sin monto → '—'. Una moneda desconocida
// para Intl no rompe: cae a número con el código al lado.
export const formatMoney = (amount, currency) => {
  if (amount === null || amount === undefined || amount === '') return '—';
  const value = Number(amount);
  if (Number.isNaN(value)) return '—';
  const code = (currency || '').toUpperCase();
  try {
    const formatted = new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: code || 'MXN',
      currencyDisplay: 'narrowSymbol',
      maximumFractionDigits: 2,
    }).format(value);
    return code ? `${formatted} ${code}` : formatted;
  } catch (_e) {
    return `${value.toLocaleString()} ${code}`.trim();
  }
};

// Totales por moneda: nunca se suman pesos con dólares. → [{ currency, total }]
export const totalsByCurrency = tickets => {
  const map = {};
  (tickets || []).forEach(t => {
    if (t.amount === null || t.amount === undefined) return;
    const code = t.currency || '';
    map[code] = (map[code] || 0) + Number(t.amount);
  });
  return Object.keys(map)
    .sort()
    .map(currency => ({ currency, total: map[currency] }));
};

// Fecha "YYYY-MM-DD" (sin hora) → texto local, sin desfase por zona horaria.
export const formatDay = day => {
  if (!day) return '—';
  const [y, m, d] = String(day).slice(0, 10).split('-').map(Number);
  if (!y) return '—';
  return new Date(y, m - 1, d).toLocaleDateString(undefined, {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
};

// "YYYY-MM-DD" de hoy + n días, en hora local (para el min del input date).
export const isoDayFromToday = (days = 0) => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

// [{ currency, amount }] → "$1,000 MXN · $500 USD"; vacío → '—'. `field` elige
// la columna (amount / weighted). Nunca suma monedas distintas.
export const moneyList = (values, field = 'amount') => {
  const list = (values || []).filter(
    v => v[field] !== undefined && v[field] !== null
  );
  if (!list.length) return '—';
  return list.map(v => formatMoney(v[field], v.currency)).join(' · ');
};
