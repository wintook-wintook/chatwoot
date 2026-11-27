// ================================================================================
// @campanas_vendedor — orden en cliente de tablas por clic en la columna
// (detalle de campaña y vista previa de audiencia). Clic 1 = ↑, clic 2 = ↓.
// ================================================================================

// Español: «Adulfo López» = «ADULFO LOPEZ»; «Contacto 2» antes que «Contacto 10».
const collator = new Intl.Collator('es', {
  sensitivity: 'base',
  numeric: true,
});

const isBlank = value =>
  value === null ||
  value === undefined ||
  (typeof value === 'string' && ['', '—'].includes(value.trim()));

// Los textos que empiezan con letra van antes que los que empiezan con emoji/número.
const startsWithLetter = text => /^\p{L}/u.test(text);

const compareValues = (x, y) => {
  if (typeof x === 'number' && typeof y === 'number') return x - y;
  const [a, b] = [String(x).trim(), String(y).trim()];
  const [letterA, letterB] = [startsWithLetter(a), startsWithLetter(b)];
  if (letterA !== letterB) return letterA ? -1 : 1;
  return collator.compare(a, b);
};

// Ordena una copia. Los vacíos (null, '', '—') quedan siempre al final, en cualquier
// dirección; los empates se resuelven por id para que el orden no salte entre renders.
export const sortRows = (rows, valueOf, direction = 'asc') => {
  if (!valueOf) return rows;
  const sign = direction === 'desc' ? -1 : 1;
  return rows
    .map(row => ({ row, value: valueOf(row) }))
    .sort((a, b) => {
      const [blankA, blankB] = [isBlank(a.value), isBlank(b.value)];
      if (blankA !== blankB) return blankA ? 1 : -1;
      const byValue = blankA ? 0 : sign * compareValues(a.value, b.value);
      return byValue || (a.row.id ?? 0) - (b.row.id ?? 0);
    })
    .map(({ row }) => row);
};

// Siguiente estado tras un clic: misma columna alterna; columna nueva arranca en su
// dirección inicial (desc para las de «más es mejor», como puntos o intentos).
export const nextSort = (current, key, descFirst = []) => {
  if (current.key === key) {
    return { key, direction: current.direction === 'asc' ? 'desc' : 'asc' };
  }
  return { key, direction: descFirst.includes(key) ? 'desc' : 'asc' };
};

export const sortArrow = (current, key) => {
  if (current.key !== key) return '↕';
  return current.direction === 'asc' ? '↑' : '↓';
};
