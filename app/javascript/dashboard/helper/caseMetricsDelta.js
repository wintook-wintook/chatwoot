// @tickets_cases — Plan-Metricas-Comercial M1: comparación contra el período
// anterior para los indicadores de «¿Cómo vamos?». Devuelve { dir, diff, good }:
//   dir  'up' | 'down' | 'same' · diff  diferencia absoluta (número)
//   good true (mejoró) / false (empeoró) / null (igual)
// Sin dato anterior → null (no se muestra flecha).

export const compareNumbers = (cur, prev, { lowerIsBetter = false } = {}) => {
  if (
    prev === null ||
    prev === undefined ||
    cur === null ||
    cur === undefined
  ) {
    return null;
  }
  const diff = Number(cur) - Number(prev);
  if (diff === 0) return { dir: 'same', diff: 0, good: null };
  const up = diff > 0;
  return {
    dir: up ? 'up' : 'down',
    diff: Math.abs(diff),
    good: up !== lowerIsBetter,
  };
};

// Montos: solo se comparan si ambos períodos están en UNA misma moneda (nunca se
// restan pesos de dólares). → { ...compareNumbers, currency } o null.
export const compareMoney = (curValues, prevValues) => {
  const cur = curValues || [];
  const prev = prevValues || [];
  const currencies = new Set([...cur, ...prev].map(v => v.currency));
  if (currencies.size !== 1) return null;
  const sum = list => list.reduce((acc, v) => acc + Number(v.amount || 0), 0);
  const result = compareNumbers(sum(cur), sum(prev));
  return result && { ...result, currency: [...currencies][0] };
};

// Ticket promedio (monto / cantidad) por moneda: [{ currency, amount }].
export const averageTicket = values =>
  (values || [])
    .filter(v => v.count)
    .map(v => ({ currency: v.currency, amount: Number(v.amount) / v.count }));

export const ARROWS = { up: '▲', down: '▼', same: '=' };
