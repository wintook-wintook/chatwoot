// @tickets_cases — Plan-Metricas-Comercial: período de calendario de las Métricas
// de todas las clases («Este mes», «Mes pasado», …) en vez de «últimos N días»,
// que corta los meses por la mitad. Cada período trae su comparación JUSTA para
// el ▲▼ (hoy solo la usa Comercial):
//   - en curso (este mes / trimestre / año) → el mismo tramo del anterior
//     (1–21 oct vs 1–21 sep), no el anterior completo, que siempre ganaría;
//   - cerrado (mes / trimestre / año pasado) → el anterior completo;
//   - personalizado → el mismo largo justo antes.
// Todo en hora local del navegador; `to` es exclusivo.

export const CALENDAR_PERIODS = [
  'this_month',
  'last_month',
  'this_quarter',
  'last_quarter',
  'this_year',
  'last_year',
  'custom',
];
export const DEFAULT_CALENDAR_PERIOD = 'this_month';

// Mismo instante n meses antes/después; el día se ajusta al largo del mes
// (31 de marzo − 1 mes → 28/29 de febrero).
export const shiftMonths = (date, n) => {
  const target = new Date(date.getFullYear(), date.getMonth() + n, 1);
  const lastDay = new Date(
    target.getFullYear(),
    target.getMonth() + 1,
    0
  ).getDate();
  target.setDate(Math.min(date.getDate(), lastDay));
  target.setHours(
    date.getHours(),
    date.getMinutes(),
    date.getSeconds(),
    date.getMilliseconds()
  );
  return target;
};

// 'YYYY-MM-DD' → Date local (00:00) o null.
export const parseDay = value => {
  const [y, m, d] = String(value || '')
    .split('-')
    .map(Number);
  return y && m && d ? new Date(y, m - 1, d) : null;
};

// Date → 'YYYY-MM-DD' local.
export const dayString = date =>
  [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, '0'),
    String(date.getDate()).padStart(2, '0'),
  ].join('-');

const calendar = (start, months, running, now) => ({
  from: start,
  to: running ? now : shiftMonths(start, months),
  prevFrom: shiftMonths(start, -months),
  prevTo: running ? shiftMonths(now, -months) : start,
});

const customRange = (fromDay, toDay) => {
  const from = parseDay(fromDay);
  const last = parseDay(toDay);
  if (!from || !last || from > last) return null;
  const to = new Date(last.getFullYear(), last.getMonth(), last.getDate() + 1);
  const length = to - from;
  return { from, to, prevFrom: new Date(from - length), prevTo: from };
};

// key → { from, to, prevFrom, prevTo } (Date) o null si no hay rango válido.
export const periodRange = (key, { now = new Date(), from, to } = {}) => {
  const y = now.getFullYear();
  const m = now.getMonth();
  const q = m - (m % 3);
  switch (key) {
    case 'this_month':
      return calendar(new Date(y, m, 1), 1, true, now);
    case 'last_month':
      return calendar(new Date(y, m - 1, 1), 1, false, now);
    case 'this_quarter':
      return calendar(new Date(y, q, 1), 3, true, now);
    case 'last_quarter':
      return calendar(new Date(y, q - 3, 1), 3, false, now);
    case 'this_year':
      return calendar(new Date(y, 0, 1), 12, true, now);
    case 'last_year':
      return calendar(new Date(y - 1, 0, 1), 12, false, now);
    case 'custom':
      return customRange(from, to);
    default:
      return null;
  }
};

// «1–21 oct» · «15 sept – 4 oct» · «1 ene – 31 dic 2025» (el año solo si no es
// el actual). `to` exclusivo.
export const formatRange = (from, to, now = new Date()) => {
  const end = new Date(to.getTime() - 1);
  const mon = d => d.toLocaleDateString(undefined, { month: 'short' });
  const year = d =>
    d.getFullYear() === now.getFullYear() ? '' : ` ${d.getFullYear()}`;
  const sameYear = from.getFullYear() === end.getFullYear();
  if (sameYear && from.getMonth() === end.getMonth()) {
    const days =
      from.getDate() === end.getDate()
        ? `${end.getDate()}`
        : `${from.getDate()}–${end.getDate()}`;
    return `${days} ${mon(end)}${year(end)}`;
  }
  const start = `${from.getDate()} ${mon(from)}${sameYear ? '' : year(from)}`;
  return `${start} – ${end.getDate()} ${mon(end)}${year(end)}`;
};

export const toEpoch = date => Math.floor(date.getTime() / 1000);
