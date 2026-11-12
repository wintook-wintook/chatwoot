// Presupuesto de ventas — utilidades compartidas por el avance y la captura.
import { formatMoney } from 'dashboard/helper/caseCommercial';

export const pad = n => String(n).padStart(2, '0');

export const monthKey = (year, month) => `${year}-${pad(month)}`;

export const yearMonths = year =>
  Array.from({ length: 12 }, (_, i) => monthKey(year, i + 1));

export const currentMonth = () => {
  const d = new Date();
  return monthKey(d.getFullYear(), d.getMonth() + 1);
};

// Rangos rápidos del avance: este mes, el trimestre y el año en curso.
export const quickRange = (kind, today = new Date()) => {
  const y = today.getFullYear();
  const m = today.getMonth() + 1;
  if (kind === 'quarter') {
    const start = Math.floor((m - 1) / 3) * 3 + 1;
    return { from: monthKey(y, start), to: monthKey(y, start + 2) };
  }
  if (kind === 'year') return { from: monthKey(y, 1), to: monthKey(y, 12) };
  return { from: monthKey(y, m), to: monthKey(y, m) };
};

export const monthLabel = key => {
  const [y, m] = key.split('-').map(Number);
  return new Date(y, m - 1, 1).toLocaleString(undefined, { month: 'short' });
};

export const money = (amount, currency) => formatMoney(amount || 0, currency);

// Montos grandes en tarjetas y ejes: $1.2 M, $350 k.
export const compactMoney = (amount, currency) => {
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: currency || 'MXN',
      currencyDisplay: 'narrowSymbol',
      notation: 'compact',
      maximumFractionDigits: 1,
    }).format(amount || 0);
  } catch {
    return money(amount, currency);
  }
};

// Cliente de un renglón: organización o, sin ella, contacto.
export const clientKey = line =>
  line.organization_id ? `o:${line.organization_id}` : `c:${line.contact_id}`;
