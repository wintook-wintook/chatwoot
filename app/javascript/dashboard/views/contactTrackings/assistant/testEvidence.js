// proyecto@diagrama_agente_ia — F4: LA PRUEBA COMO EVIDENCIA
// ============================================================================
// Plan: docs/diagrama_agente_ia_plan.md §4.4 y §5. Funciones puras:
//
//   pathSummary     el camino de una corrida en una línea («cotizar → Google Doc ·
//                   Lista (3 fragmentos · mejor 0.41) → #cotizar»): para el antes /
//                   después y para la evidencia
//   evidenceMessage lo que «Llevar al chat» escribe en el chat de creación: cliente,
//                   respuesta, camino y veredicto de una o varias pruebas, y la
//                   pregunta para que el Asistente proponga el cambio
//   compareRuns     la pila en vivo antes y ahora: cuántas cumplían, cuántas cumplen,
//                   cuáles se arreglaron y cuáles se rompieron (las que pasaban y ya no)
//
// `t` es la función de traducción ($t) ya apuntando a TRACKING_ASSISTANT_VIEW.TESTS.
//
// OJO con la evidencia: no puede decir «conversación 173». El chat toma ese patrón
// como «revisa esta conversación real» (conversationReview.js) y el turno no iría
// al Asistente sino a la revisión. Por eso el número va como «prueba #173».
// ============================================================================

const MAX_EVIDENCE = 5;
const MAX_REPLY = 600;

const truncate = (texto, max) => {
  const limpio = (texto || '').trim();
  return limpio.length > max ? `${limpio.slice(0, max - 1)}…` : limpio;
};

const fragmentsText = (items, t) => {
  if (!items || !items.length) return '';
  const mejor = Math.max(
    ...items.map(i => Number(i.similitud || i.similarity || 0))
  );
  return t('EVIDENCE_FRAGMENTS', {
    count: items.length,
    best: mejor.toFixed(2),
  });
};

const sourceText = (modo, nombre) => [modo, nombre].filter(Boolean).join(' · ');

const tagsIn = texto => (texto || '').match(/#[a-z0-9_]{3,}/gi) || [];

// El camino en vivo, desde la traza del motor (F0).
const livePath = (vivo, t) => {
  const traza = vivo.traza;
  if (!traza) return t('EVIDENCE_NO_TRACE');
  const partes = [];
  if (traza.camino === 'bienvenida') return t('EVIDENCE_WELCOME');
  partes.push(
    traza.ruta && traza.ruta.nombre ? traza.ruta.nombre : t('EVIDENCE_NO_ROUTE')
  );
  if (traza.fuente) {
    const fuente = sourceText(traza.fuente.modo, traza.fuente.nombre);
    const frag = fragmentsText(traza.fragmentos, t);
    partes.push(frag ? `${fuente} (${frag})` : fuente);
  }
  if (traza.camino)
    partes.push(t('EVIDENCE_ANSWERED_BY', { camino: traza.camino }));
  const etiquetas = tagsIn(vivo.reply);
  if (etiquetas.length) partes.push(etiquetas.join(' '));
  return partes.join(' → ');
};

// El camino en seco, desde el informe de DryRunService.
const dryPath = (informe, t) => {
  const rutas = informe.routes || {};
  if (rutas.none_declared) return t('EVIDENCE_NO_ROUTES');
  const partes = [rutas.chosen || t('EVIDENCE_NO_ROUTE')];
  const fuente = informe.source || {};
  if (fuente.reason === 'no_source') partes.push(t('EVIDENCE_NO_SOURCE'));
  else if (fuente.mode) {
    const frag = fragmentsText(fuente.items, t);
    const nombre = sourceText(fuente.mode, fuente.source_name);
    partes.push(frag ? `${nombre} (${frag})` : nombre);
    if (fuente.reason)
      partes.push(t('EVIDENCE_REASON', { reason: fuente.reason }));
  }
  if (informe.case && informe.case.creates) partes.push(t('EVIDENCE_CASE'));
  if (informe.tag) partes.push(informe.tag);
  return partes.join(' → ');
};

export function pathSummary(modo, datos, t) {
  if (!datos) return '';
  return modo === 'live' ? livePath(datos, t) : dryPath(datos, t);
}

const verdict = vivo => {
  if (!vivo) return '';
  const marca = vivo.cumple ? '✅' : '❌';
  const fallas = (vivo.fallas || []).filter(Boolean);
  return [marca, vivo.motivo, fallas.length ? `(${fallas.join(' · ')})` : '']
    .filter(Boolean)
    .join(' ');
};

// Una prueba de la pila (como la arma TestsPanel: message, live, dry, conversation).
const evidenceBlock = (fila, t, n) => {
  const lineas = [
    t('EVIDENCE_TITLE', {
      n,
      mode: fila.live ? t('EVIDENCE_LIVE') : t('EVIDENCE_DRY'),
    }),
  ];
  lineas.push(`${t('CUSTOMER')} ${fila.message}`);
  if (fila.live) {
    lineas.push(
      `${t('AGENT')} ${truncate(fila.live.reply, MAX_REPLY) || t('NO_REPLY')}`
    );
    lineas.push(`${t('EVIDENCE_PATH')} ${pathSummary('live', fila.live, t)}`);
    lineas.push(`${t('VERDICT')} ${verdict(fila.live)}`);
    if (fila.live.conversation)
      lineas.push(t('EVIDENCE_TEST_ID', { id: fila.live.conversation }));
  } else if (fila.dry) {
    lineas.push(`${t('EVIDENCE_PATH')} ${pathSummary('dry', fila.dry, t)}`);
  }
  return lineas.join('\n');
};

export function evidenceMessage(filas, t) {
  const elegidas = (filas || [])
    .filter(f => f.live || f.dry)
    .slice(0, MAX_EVIDENCE);
  if (!elegidas.length) return '';
  const bloques = elegidas.map((f, i) => evidenceBlock(f, t, i + 1));
  return [
    t('EVIDENCE_INTRO', { count: elegidas.length }),
    ...bloques,
    t('EVIDENCE_ASK'),
  ].join('\n\n');
}

// La pila en vivo antes (previous_live) y ahora (last_live). Solo cuentan las que
// tienen las dos corridas: comparar contra nada no dice si algo se rompió.
export function compareRuns(cases = []) {
  const dobles = cases.filter(
    c => c.previous_live && c.previous_live.at && c.last_live && c.last_live.at
  );
  const cumple = r => r.cumple === true;
  return {
    compared: dobles.length,
    before: dobles.filter(c => cumple(c.previous_live)).length,
    after: dobles.filter(c => cumple(c.last_live)).length,
    broken: dobles.filter(c => cumple(c.previous_live) && !cumple(c.last_live)),
    fixed: dobles.filter(c => !cumple(c.previous_live) && cumple(c.last_live)),
  };
}
