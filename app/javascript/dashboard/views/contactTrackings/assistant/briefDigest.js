// proyecto@asistente_agentes_ia — LA FICHA DEL ENCARGO, PARA LEERLA
// ============================================================================
// Lo que el backend devuelve (BriefFicha + BriefGaps) viene pensado para el
// Asistente: un punto por falta, con su paso. En pantalla se lee mejor agrupado:
// "Frases del cliente: reclamo, urgencia" en vez de dos renglones iguales.
// ============================================================================

// Orden en que se muestran las faltas: el de los pasos de la entrevista.
// Las contradicciones primero: son decisiones, no datos que falten.
const GAP_ORDER = [
  'contradiccion',
  'temas',
  'modo',
  'frases_cliente',
  'fuente_o_escalamiento',
  'herramienta_no_disponible',
  'etiquetas',
  'etiqueta',
];

// [{ que, items: ['tema A', 'tema B'] }] — `items` vacío cuando la falta no es de un
// tema (el modo, "ningún tema trae etiqueta").
export const groupGaps = (gaps = []) => {
  const grupos = new Map();
  gaps.forEach(gap => {
    const que = gap.que === 'etiqueta' ? 'etiquetas' : gap.que;
    if (!grupos.has(que)) grupos.set(que, []);
    const item =
      gap.que === 'contradiccion'
        ? `${gap.sobre}: «${gap.a}» o «${gap.b}»`
        : gap.tema || gap.tipo;
    if (item && !grupos.get(que).includes(item)) grupos.get(que).push(item);
  });
  return [...grupos.entries()]
    .sort(([a], [b]) => GAP_ORDER.indexOf(a) - GAP_ORDER.indexOf(b))
    .map(([que, items]) => ({ que, items }));
};

// El texto de un punto, sea de lista de texto o un campo suelto.
export const pointText = point => (point && point.texto) || '';

// La ficha, en las listas que se muestran y con cuántos puntos tiene cada una.
export const LIST_FIELDS = [
  'reglas',
  'prohibiciones',
  'tono',
  'datos_a_pedir',
  'conocimiento',
  'contradicciones',
  'fuera',
  'dudas',
];

export const listSizes = (ficha = {}) =>
  LIST_FIELDS.map(campo => ({
    campo,
    count: (ficha[campo] || []).length,
  })).filter(({ count }) => count > 0);

// El texto de un punto de cualquier lista: los objetos (conocimiento,
// contradicciones) no tienen "texto".
export const listItemText = (campo, punto) => {
  if (campo === 'conocimiento') return `${punto.tema}: ${punto.resumen || ''}`;
  if (campo === 'contradicciones') {
    return `${punto.sobre}: «${punto.a}» / «${punto.b}»`;
  }
  return pointText(punto);
};

export const isBusy = status => ['pending', 'reading'].includes(status);

// Las preguntas del formulario, desde las faltas crudas (no las agrupadas: cada tema
// lleva su propio campo). Las contradicciones van por su índice en la ficha, que es
// como las identifica el backend al armar el encargo (BriefComposer).
export const briefQuestions = (ficha = {}, gaps = []) => {
  const preguntas = (ficha.contradicciones || []).map((c, index) => ({
    kind: 'contradiccion',
    key: String(index),
    ...c,
  }));
  gaps.forEach(gap => {
    if (gap.que === 'modo') preguntas.push({ kind: 'modo', key: 'modo' });
    if (gap.que === 'temas') preguntas.push({ kind: 'temas', key: 'temas' });
    if (gap.que === 'frases_cliente')
      preguntas.push({ kind: 'frases', key: gap.tema, tema: gap.tema });
    if (gap.que === 'fuente_o_escalamiento')
      preguntas.push({ kind: 'fuentes', key: gap.tema, tema: gap.tema });
  });
  const sinEtiqueta = (ficha.temas || []).filter(t => !t.etiqueta);
  sinEtiqueta.forEach(t =>
    preguntas.push({ kind: 'etiquetas', key: t.nombre, tema: t.nombre })
  );
  return preguntas;
};

// Las respuestas en la forma que espera el backend, sin las vacías.
export const briefAnswers = (values = {}) => {
  const respuestas = {};
  Object.entries(values).forEach(([id, valor]) => {
    const texto = typeof valor === 'string' ? valor.trim() : valor;
    if (!texto) return;
    const [kind, ...resto] = id.split(':');
    const key = resto.join(':');
    if (kind === 'modo' || kind === 'temas') {
      respuestas[kind] = texto;
      return;
    }
    const grupo = kind === 'contradiccion' ? 'contradicciones' : kind;
    respuestas[grupo] = { ...(respuestas[grupo] || {}), [key]: texto };
  });
  return respuestas;
};
