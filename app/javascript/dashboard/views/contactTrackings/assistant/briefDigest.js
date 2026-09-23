// proyecto@asistente_agentes_ia — LA FICHA DEL ENCARGO, PARA LEERLA
// ============================================================================
// Lo que el backend devuelve (BriefFicha + BriefGaps) viene pensado para el
// Asistente: un punto por falta, con su paso. En pantalla se lee mejor agrupado:
// "Frases del cliente: reclamo, urgencia" en vez de dos renglones iguales.
// ============================================================================

// Orden en que se muestran las faltas: el de los pasos de la entrevista.
const GAP_ORDER = [
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
    const item = gap.tema || gap.tipo;
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
