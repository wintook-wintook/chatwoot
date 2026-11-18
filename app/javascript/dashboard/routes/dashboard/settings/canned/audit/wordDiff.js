// proyecto@arreglar_predefinidas F2 — los cambios de un texto, palabra por palabra, para
// enseñar «Mejorar redacción» y «Resolver» como control de cambios. Misma medida que el
// servidor (CannedResponses::Fix::Diff): subsecuencia común más larga sobre palabras; los
// espacios viajan pegados a la palabra para no perder saltos de línea.
const MAX_TOKENS = 1500;

const tokens = text =>
  (text || '').match(/\S+\s*/g)?.slice(0, MAX_TOKENS) || [];

// [{ type: 'same' | 'del' | 'ins', text }]
export const wordDiff = (before, after) => {
  const a = tokens(before);
  const b = tokens(after);
  const tabla = Array.from({ length: a.length + 1 }, () =>
    new Array(b.length + 1).fill(0)
  );
  for (let i = a.length - 1; i >= 0; i -= 1) {
    for (let j = b.length - 1; j >= 0; j -= 1) {
      tabla[i][j] =
        a[i].trim() === b[j].trim()
          ? tabla[i + 1][j + 1] + 1
          : Math.max(tabla[i + 1][j], tabla[i][j + 1]);
    }
  }
  const out = [];
  const push = (type, text) => {
    const last = out[out.length - 1];
    if (last && last.type === type) last.text += text;
    else out.push({ type, text });
  };
  let i = 0;
  let j = 0;
  while (i < a.length && j < b.length) {
    if (a[i].trim() === b[j].trim()) {
      push('same', b[j]);
      i += 1;
      j += 1;
    } else if (tabla[i + 1][j] >= tabla[i][j + 1]) {
      push('del', a[i]);
      i += 1;
    } else {
      push('ins', b[j]);
      j += 1;
    }
  }
  a.slice(i).forEach(t => push('del', t));
  b.slice(j).forEach(t => push('ins', t));
  return out;
};

const escapeHtml = text =>
  text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

// HTML seguro (todo escapado) con <del>/<ins> para v-html.
export const diffHtml = (before, after) =>
  wordDiff(before, after)
    .map(({ type, text }) => {
      const t = escapeHtml(text);
      if (type === 'del')
        return `<del class="text-red-700 dark:text-red-300 bg-red-50 dark:bg-red-900/40">${t}</del>`;
      if (type === 'ins')
        return `<ins class="no-underline text-green-800 dark:text-green-200 bg-green-50 dark:bg-green-900/40">${t}</ins>`;
      return t;
    })
    .join('');
