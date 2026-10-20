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
