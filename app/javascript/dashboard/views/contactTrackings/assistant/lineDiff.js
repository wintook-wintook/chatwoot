// proyecto@asistente_agentes_ia — fase D de PROMPT STUDIO
// ============================================================================
// Diferencias por línea entre dos Entrenamientos, para "comparar con la actual".
// LCS clásico: en esta cuenta los Entrenamientos llegan a 645 líneas, o sea
// ~400.000 celdas en el peor caso, que es nada para el navegador. Una librería
// para esto sería más código del que reemplaza.
// ============================================================================

const table = (a, b) => {
  const rows = Array.from(
    { length: a.length + 1 },
    () => new Uint16Array(b.length + 1)
  );
  for (let i = a.length - 1; i >= 0; i -= 1) {
    for (let j = b.length - 1; j >= 0; j -= 1) {
      rows[i][j] =
        a[i] === b[j]
          ? rows[i + 1][j + 1] + 1
          : Math.max(rows[i + 1][j], rows[i][j + 1]);
    }
  }
  return rows;
};

// [{ type: 'same' | 'del' | 'add', text }] — del = solo en `before`.
export const lineDiff = (before, after) => {
  const a = String(before || '').split('\n');
  const b = String(after || '').split('\n');
  const lcs = table(a, b);
  const out = [];
  let i = 0;
  let j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) {
      out.push({ type: 'same', text: a[i] });
      i += 1;
      j += 1;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      out.push({ type: 'del', text: a[i] });
      i += 1;
    } else {
      out.push({ type: 'add', text: b[j] });
      j += 1;
    }
  }
  while (i < a.length) out.push({ type: 'del', text: a[(i += 1) - 1] });
  while (j < b.length) out.push({ type: 'add', text: b[(j += 1) - 1] });
  return out;
};

// Solo lo que cambió, con `context` líneas iguales alrededor. Lo demás se resume
// como { type: 'skip', count } para no mostrar 198 líneas por una distinta.
export const diffHunks = (before, after, context = 2) => {
  const lines = lineDiff(before, after);
  const near = lines.map((line, index) =>
    lines
      .slice(Math.max(0, index - context), index + context + 1)
      .some(other => other.type !== 'same')
  );
  const out = [];
  lines.forEach((line, index) => {
    if (near[index]) {
      out.push(line);
      return;
    }
    const last = out[out.length - 1];
    if (last && last.type === 'skip') last.count += 1;
    else out.push({ type: 'skip', count: 1 });
  });
  return out;
};

export const diffStats = (before, after) =>
  lineDiff(before, after).reduce(
    (acc, line) => {
      if (line.type === 'add') acc.added += 1;
      if (line.type === 'del') acc.removed += 1;
      return acc;
    },
    { added: 0, removed: 0 }
  );
